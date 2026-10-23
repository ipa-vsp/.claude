#include <gtest/gtest.h>

#include <cmath>
#include <limits>
#include <memory>
#include <string>

#include <hardware_interface/resource_manager.hpp>
#include <rclcpp/rclcpp.hpp>

namespace {

std::string joint_xml(const std::string & name, const std::string & init)
{
  return "<joint name=\"" + name + "\"><command_interface name=\"position\"/>"
         "<state_interface name=\"position\"><param name=\"initial_value\">" + init +
         "</param></state_interface><state_interface name=\"velocity\"/></joint>";
}

std::string urdf(const std::string & hw_params, const std::string & joints)
{
  return R"(<?xml version="1.0"?><robot name="twojoint">
<link name="base"/><link name="l1"/><link name="l2"/>
<joint name="joint1" type="revolute"><parent link="base"/><child link="l1"/>
<limit lower="-3" upper="3" effort="10" velocity="2"/></joint>
<joint name="joint2" type="revolute"><parent link="l1"/><child link="l2"/>
<limit lower="-3" upper="3" effort="10" velocity="2"/></joint>
<ros2_control name="TwoJoint" type="system"><hardware>
<plugin>twojoint_hardware/TwoJointSystem</plugin>)" + hw_params + "</hardware>" + joints +
         "</ros2_control></robot>";
}

const std::string kGoodJoints = joint_xml("joint1", "0.1") + joint_xml("joint2", "-0.2");

class TwoJointAcceptance : public ::testing::Test {
 protected:
  static void SetUpTestSuite() { rclcpp::init(0, nullptr); }
  static void TearDownTestSuite() { rclcpp::shutdown(); }
  void SetUp() override { node_ = std::make_shared<rclcpp::Node>("twojoint_acceptance"); }

  std::unique_ptr<hardware_interface::ResourceManager> make(const std::string & description)
  {
    return std::make_unique<hardware_interface::ResourceManager>(
      description, node_->get_node_clock_interface(), node_->get_node_logging_interface(), true, 100);
  }

  static void cycle(hardware_interface::ResourceManager & rm, int n)
  {
    rclcpp::Time t(0, 0, RCL_ROS_TIME);
    const rclcpp::Duration dt = rclcpp::Duration::from_seconds(0.01);
    for (int i = 0; i < n; ++i) {
      rm.read(t, dt);
      rm.write(t, dt);
      t += dt;
    }
  }

  rclcpp::Node::SharedPtr node_;
};

double value(hardware_interface::ResourceManager & rm, const std::string & key)
{
  auto s = rm.claim_state_interface(key);
  const auto v = s.get_optional<double>();
  EXPECT_TRUE(v.has_value()) << key;
  return v.value_or(std::numeric_limits<double>::quiet_NaN());
}

}  // namespace

TEST_F(TwoJointAcceptance, ExportsInterfacesAndInitialValues)
{
  auto rm = make(urdf("<param name=\"time_constant\">0.05</param>", kGoodJoints));
  for (const char * k : {"joint1/position", "joint1/velocity", "joint2/position", "joint2/velocity"}) {
    EXPECT_TRUE(rm->state_interface_is_available(k)) << k;
  }
  EXPECT_TRUE(rm->command_interface_is_available("joint1/position"));
  EXPECT_TRUE(rm->command_interface_is_available("joint2/position"));
  EXPECT_NEAR(value(*rm, "joint1/position"), 0.1, 1e-9);
  EXPECT_NEAR(value(*rm, "joint2/position"), -0.2, 1e-9);
}

TEST_F(TwoJointAcceptance, HoldsPositionAfterActivation)
{
  auto rm = make(urdf("<param name=\"time_constant\">0.05</param>", kGoodJoints));
  cycle(*rm, 50);
  EXPECT_NEAR(value(*rm, "joint1/position"), 0.1, 1e-6);
  EXPECT_NEAR(value(*rm, "joint2/position"), -0.2, 1e-6);
}

TEST_F(TwoJointAcceptance, TracksCommandWithLag)
{
  auto rm = make(urdf("<param name=\"time_constant\">0.05</param>", kGoodJoints));
  auto cmd = rm->claim_command_interface("joint1/position");
  ASSERT_TRUE(cmd.set_value(0.6));
  cycle(*rm, 1);
  const double after_one = value(*rm, "joint1/position");
  EXPECT_GT(after_one, 0.1);
  EXPECT_LT(after_one, 0.6) << "should lag, not jump";
  EXPECT_GT(value(*rm, "joint1/velocity"), 0.0);
  cycle(*rm, 200);
  EXPECT_NEAR(value(*rm, "joint1/position"), 0.6, 1e-3);
  EXPECT_NEAR(value(*rm, "joint1/velocity"), 0.0, 1e-2);
  EXPECT_NEAR(value(*rm, "joint2/position"), -0.2, 1e-6);
}

TEST_F(TwoJointAcceptance, NanCommandHolds)
{
  auto rm = make(urdf("<param name=\"time_constant\">0.05</param>", kGoodJoints));
  auto cmd = rm->claim_command_interface("joint2/position");
  ASSERT_TRUE(cmd.set_value(std::numeric_limits<double>::quiet_NaN()));
  cycle(*rm, 20);
  const double p = value(*rm, "joint2/position");
  EXPECT_FALSE(std::isnan(p));
  EXPECT_NEAR(p, -0.2, 1e-6);
}

TEST_F(TwoJointAcceptance, RejectsBadConfiguration)
{
  for (const std::string & hw : {std::string(""), std::string("<param name=\"time_constant\">-1</param>")}) {
    std::unique_ptr<hardware_interface::ResourceManager> rm;
    try {
      rm = make(urdf(hw, kGoodJoints));
    } catch (const std::exception &) {
      continue;  // refusing to load is fine
    }
    EXPECT_FALSE(rm->command_interface_is_available("joint1/position")) << "accepted hw params: " << hw;
  }
  const std::string missing_velocity =
    "<joint name=\"joint1\"><command_interface name=\"position\"/>"
    "<state_interface name=\"position\"/></joint>" + joint_xml("joint2", "0");
  std::unique_ptr<hardware_interface::ResourceManager> rm;
  try {
    rm = make(urdf("<param name=\"time_constant\">0.05</param>", missing_velocity));
  } catch (const std::exception &) {
    return;
  }
  EXPECT_FALSE(rm->command_interface_is_available("joint1/position"));
}
