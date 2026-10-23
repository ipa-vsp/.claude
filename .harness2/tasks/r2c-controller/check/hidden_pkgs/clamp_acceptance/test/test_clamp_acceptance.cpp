#include <gtest/gtest.h>

#include <chrono>
#include <cmath>
#include <limits>
#include <memory>
#include <string>
#include <vector>

#include <controller_interface/controller_interface.hpp>
#include <hardware_interface/handle.hpp>
#include <hardware_interface/loaned_command_interface.hpp>
#include <lifecycle_msgs/msg/state.hpp>
#include <pluginlib/class_loader.hpp>
#include <rclcpp/rclcpp.hpp>
#include <std_msgs/msg/float64_multi_array.hpp>

#include "clamp_forward_controller/clamp_forward_controller.hpp"

using controller_interface::ControllerInterfaceParams;
using hardware_interface::CommandInterface;
using lifecycle_msgs::msg::State;
using std_msgs::msg::Float64MultiArray;
using namespace std::chrono_literals;

namespace {

CommandInterface::SharedPtr make_cmd(const std::string & joint, const std::string & iface)
{
  hardware_interface::InterfaceInfo info;
  info.name = iface;
  info.initial_value = "0.0";
  return std::make_shared<CommandInterface>(hardware_interface::InterfaceDescription(joint, info));
}

double val(const CommandInterface::SharedPtr & c)
{
  return c->get_optional<double>().value_or(std::numeric_limits<double>::quiet_NaN());
}

class ClampAcceptance : public ::testing::Test {
 protected:
  static void SetUpTestSuite() { rclcpp::init(0, nullptr); }
  static void TearDownTestSuite() { rclcpp::shutdown(); }

  void SetUp() override
  {
    ctrl_ = std::make_shared<clamp_forward_controller::ClampForwardController>();
    probe_ = std::make_shared<rclcpp::Node>("clamp_probe");
  }

  controller_interface::return_type init(std::vector<rclcpp::Parameter> params)
  {
    ControllerInterfaceParams p;
    p.controller_name = "clamp";
    p.robot_description = "";
    p.update_rate = 100;
    p.controller_manager_update_rate = 100;
    p.node_namespace = "";
    p.node_options = ctrl_->define_custom_node_options();
    p.node_options.parameter_overrides(params);
    return ctrl_->init(p);
  }

  static std::vector<rclcpp::Parameter> good_params()
  {
    return {
      rclcpp::Parameter("joints", std::vector<std::string>{"j1", "j2"}),
      rclcpp::Parameter("lower_limits", std::vector<double>{-1.0, 0.0}),
      rclcpp::Parameter("upper_limits", std::vector<double>{1.0, 0.5}),
    };
  }

  void activate_with(const std::string & iface)
  {
    std::vector<hardware_interface::LoanedCommandInterface> loaned;
    for (auto & c : cmds_) { loaned.emplace_back(c); }
    ctrl_->assign_interfaces(std::move(loaned), {});
    ASSERT_EQ(ctrl_->get_node()->activate().id(), State::PRIMARY_STATE_ACTIVE) << iface;
  }

  // Publish until the controller applies something different from `before` (bounded, no sleeps).
  bool publish_and_update(const std::vector<double> & data, const std::vector<double> & before)
  {
    auto pub = probe_->create_publisher<Float64MultiArray>("/clamp/commands", rclcpp::SystemDefaultsQoS());
    rclcpp::executors::SingleThreadedExecutor exec;
    exec.add_node(ctrl_->get_node()->get_node_base_interface());
    exec.add_node(probe_);
    Float64MultiArray msg;
    msg.data = data;
    const auto deadline = std::chrono::steady_clock::now() + 5s;
    while (std::chrono::steady_clock::now() < deadline) {
      pub->publish(msg);
      exec.spin_some(20ms);
      ctrl_->update(rclcpp::Time(0, 0, RCL_ROS_TIME), rclcpp::Duration::from_seconds(0.01));
      for (std::size_t i = 0; i < cmds_.size(); ++i) {
        const double v = val(cmds_[i]);
        if (!(v == before[i] || (std::isnan(v) && std::isnan(before[i])))) { return true; }
      }
    }
    return false;
  }

  std::shared_ptr<clamp_forward_controller::ClampForwardController> ctrl_;
  rclcpp::Node::SharedPtr probe_;
  std::vector<CommandInterface::SharedPtr> cmds_;
};

}  // namespace

TEST_F(ClampAcceptance, PluginIsExported)
{
  pluginlib::ClassLoader<controller_interface::ControllerInterface> loader(
    "controller_interface", "controller_interface::ControllerInterface");
  EXPECT_NO_THROW({ auto c = loader.createSharedInstance("clamp_forward_controller/ClampForwardController"); });
}

TEST_F(ClampAcceptance, InterfaceConfiguration)
{
  auto params = good_params();
  params.emplace_back("interface_name", "velocity");
  ASSERT_EQ(init(params), controller_interface::return_type::OK);
  ASSERT_EQ(ctrl_->configure().id(), State::PRIMARY_STATE_INACTIVE);
  const auto cfg = ctrl_->command_interface_configuration();
  EXPECT_EQ(cfg.type, controller_interface::interface_configuration_type::INDIVIDUAL);
  EXPECT_EQ(cfg.names, (std::vector<std::string>{"j1/velocity", "j2/velocity"}));
  EXPECT_EQ(ctrl_->state_interface_configuration().type,
    controller_interface::interface_configuration_type::NONE);
}

TEST_F(ClampAcceptance, RejectsMismatchedLimits)
{
  ASSERT_EQ(init({rclcpp::Parameter("joints", std::vector<std::string>{"j1", "j2"}),
                  rclcpp::Parameter("lower_limits", std::vector<double>{-1.0}),
                  rclcpp::Parameter("upper_limits", std::vector<double>{1.0, 1.0})}),
    controller_interface::return_type::OK);
  EXPECT_EQ(ctrl_->configure().id(), State::PRIMARY_STATE_UNCONFIGURED);
}

TEST_F(ClampAcceptance, RejectsInvertedLimits)
{
  ASSERT_EQ(init({rclcpp::Parameter("joints", std::vector<std::string>{"j1"}),
                  rclcpp::Parameter("lower_limits", std::vector<double>{1.0}),
                  rclcpp::Parameter("upper_limits", std::vector<double>{-1.0})}),
    controller_interface::return_type::OK);
  EXPECT_EQ(ctrl_->configure().id(), State::PRIMARY_STATE_UNCONFIGURED);
}

TEST_F(ClampAcceptance, ClampsAndSkipsNaN)
{
  ASSERT_EQ(init(good_params()), controller_interface::return_type::OK);
  ASSERT_EQ(ctrl_->configure().id(), State::PRIMARY_STATE_INACTIVE);
  cmds_ = {make_cmd("j1", "position"), make_cmd("j2", "position")};
  activate_with("position");

  // Nothing written before the first message.
  ctrl_->update(rclcpp::Time(0, 0, RCL_ROS_TIME), rclcpp::Duration::from_seconds(0.01));
  EXPECT_DOUBLE_EQ(val(cmds_[0]), 0.0);
  EXPECT_DOUBLE_EQ(val(cmds_[1]), 0.0);

  ASSERT_TRUE(publish_and_update({5.0, -3.0}, {0.0, 0.0}));
  EXPECT_DOUBLE_EQ(val(cmds_[0]), 1.0);
  EXPECT_DOUBLE_EQ(val(cmds_[1]), 0.0);

  ASSERT_TRUE(publish_and_update({0.25, 0.25}, {1.0, 0.0}));
  EXPECT_DOUBLE_EQ(val(cmds_[0]), 0.25);
  EXPECT_DOUBLE_EQ(val(cmds_[1]), 0.25);

  ASSERT_TRUE(publish_and_update({std::numeric_limits<double>::quiet_NaN(), 0.4}, {0.25, 0.25}));
  EXPECT_DOUBLE_EQ(val(cmds_[0]), 0.25) << "NaN must keep the previous command";
  EXPECT_DOUBLE_EQ(val(cmds_[1]), 0.4);

  // Wrong size is ignored.
  EXPECT_FALSE(publish_and_update({0.1, 0.1, 0.1}, {0.25, 0.4}));
  EXPECT_DOUBLE_EQ(val(cmds_[0]), 0.25);
}

TEST_F(ClampAcceptance, NoStaleReplayAfterReactivation)
{
  ASSERT_EQ(init(good_params()), controller_interface::return_type::OK);
  ASSERT_EQ(ctrl_->configure().id(), State::PRIMARY_STATE_INACTIVE);
  cmds_ = {make_cmd("j1", "position"), make_cmd("j2", "position")};
  activate_with("position");
  ASSERT_TRUE(publish_and_update({0.5, 0.3}, {0.0, 0.0}));
  ASSERT_EQ(ctrl_->get_node()->deactivate().id(), State::PRIMARY_STATE_INACTIVE);
  ctrl_->release_interfaces();
  ASSERT_TRUE(cmds_[0]->set_value(-0.7));
  ASSERT_TRUE(cmds_[1]->set_value(0.1));
  activate_with("position");
  for (int i = 0; i < 5; ++i) {
    ctrl_->update(rclcpp::Time(0, 0, RCL_ROS_TIME), rclcpp::Duration::from_seconds(0.01));
  }
  EXPECT_DOUBLE_EQ(val(cmds_[0]), -0.7);
  EXPECT_DOUBLE_EQ(val(cmds_[1]), 0.1);
}
