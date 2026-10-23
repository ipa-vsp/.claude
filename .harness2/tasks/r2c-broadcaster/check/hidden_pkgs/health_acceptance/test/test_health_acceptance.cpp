#include <gtest/gtest.h>

#include <chrono>
#include <limits>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include <controller_interface/controller_interface.hpp>
#include <diagnostic_msgs/msg/diagnostic_array.hpp>
#include <diagnostic_msgs/msg/diagnostic_status.hpp>
#include <hardware_interface/handle.hpp>
#include <hardware_interface/loaned_state_interface.hpp>
#include <lifecycle_msgs/msg/state.hpp>
#include <pluginlib/class_loader.hpp>
#include <rclcpp/rclcpp.hpp>

#include "joint_health_broadcaster/joint_health_broadcaster.hpp"

using diagnostic_msgs::msg::DiagnosticArray;
using diagnostic_msgs::msg::DiagnosticStatus;
using hardware_interface::StateInterface;
using lifecycle_msgs::msg::State;
using namespace std::chrono_literals;

namespace {

StateInterface::SharedPtr make_state(const std::string & joint, const std::string & iface, double v)
{
  hardware_interface::InterfaceInfo info;
  info.name = iface;
  info.initial_value = std::to_string(v);
  return std::make_shared<StateInterface>(hardware_interface::InterfaceDescription(joint, info));
}

class HealthAcceptance : public ::testing::Test {
 protected:
  static void SetUpTestSuite() { rclcpp::init(0, nullptr); }
  static void TearDownTestSuite() { rclcpp::shutdown(); }
  void SetUp() override
  {
    ctrl_ = std::make_shared<joint_health_broadcaster::JointHealthBroadcaster>();
    probe_ = std::make_shared<rclcpp::Node>("health_probe");
  }

  controller_interface::return_type init(std::vector<rclcpp::Parameter> params)
  {
    controller_interface::ControllerInterfaceParams p;
    p.controller_name = "health";
    p.update_rate = 100;
    p.controller_manager_update_rate = 100;
    p.node_options = ctrl_->define_custom_node_options();
    p.node_options.parameter_overrides(params);
    return ctrl_->init(p);
  }

  std::optional<DiagnosticArray> next_message()
  {
    std::optional<DiagnosticArray> got;
    auto sub = probe_->create_subscription<DiagnosticArray>(
      "/health/health", rclcpp::SystemDefaultsQoS(),
      [&got](DiagnosticArray::ConstSharedPtr m) { got = *m; });
    rclcpp::executors::SingleThreadedExecutor exec;
    exec.add_node(probe_);
    exec.add_node(ctrl_->get_node()->get_node_base_interface());
    const auto deadline = std::chrono::steady_clock::now() + 5s;
    while (!got && std::chrono::steady_clock::now() < deadline) {
      ctrl_->update(rclcpp::Time(0, 0, RCL_ROS_TIME), rclcpp::Duration::from_seconds(0.01));
      exec.spin_some(20ms);
    }
    return got;
  }

  std::shared_ptr<joint_health_broadcaster::JointHealthBroadcaster> ctrl_;
  rclcpp::Node::SharedPtr probe_;
  std::vector<StateInterface::SharedPtr> states_;
};

}  // namespace

TEST_F(HealthAcceptance, PluginIsExported)
{
  pluginlib::ClassLoader<controller_interface::ControllerInterface> loader(
    "controller_interface", "controller_interface::ControllerInterface");
  EXPECT_NO_THROW({ auto c = loader.createSharedInstance("joint_health_broadcaster/JointHealthBroadcaster"); });
}

TEST_F(HealthAcceptance, RejectsBadThresholds)
{
  ASSERT_EQ(init({rclcpp::Parameter("joints", std::vector<std::string>{"a"}),
                  rclcpp::Parameter("velocity_warn", 3.0), rclcpp::Parameter("velocity_error", 2.0)}),
    controller_interface::return_type::OK);
  EXPECT_EQ(ctrl_->configure().id(), State::PRIMARY_STATE_UNCONFIGURED);
}

TEST_F(HealthAcceptance, PublishesLevels)
{
  ASSERT_EQ(init({rclcpp::Parameter("joints", std::vector<std::string>{"a", "b", "c", "d"})}),
    controller_interface::return_type::OK);
  ASSERT_EQ(ctrl_->configure().id(), State::PRIMARY_STATE_INACTIVE);
  const auto cfg = ctrl_->state_interface_configuration();
  EXPECT_EQ(cfg.names, (std::vector<std::string>{"a/position", "a/velocity", "b/position",
    "b/velocity", "c/position", "c/velocity", "d/position", "d/velocity"}));
  EXPECT_EQ(ctrl_->command_interface_configuration().type,
    controller_interface::interface_configuration_type::NONE);

  states_ = {make_state("a", "position", 0.1), make_state("a", "velocity", 0.5),
             make_state("b", "position", 0.2), make_state("b", "velocity", -1.5),
             make_state("c", "position", 0.3), make_state("c", "velocity", 2.5),
             make_state("d", "position", 0.4), make_state("d", "velocity", 0.0)};
  ASSERT_TRUE(states_[7]->set_value(std::numeric_limits<double>::quiet_NaN(), true));
  std::vector<hardware_interface::LoanedStateInterface> loaned;
  for (auto & s : states_) { loaned.emplace_back(s); }
  ctrl_->assign_interfaces({}, std::move(loaned));
  ASSERT_EQ(ctrl_->get_node()->activate().id(), State::PRIMARY_STATE_ACTIVE);

  const auto msg = next_message();
  ASSERT_TRUE(msg.has_value()) << "no DiagnosticArray on /health/health";
  ASSERT_EQ(msg->status.size(), 4U);
  EXPECT_EQ(msg->status[0].name, "a");
  EXPECT_EQ(msg->status[0].level, DiagnosticStatus::OK);
  EXPECT_EQ(msg->status[1].level, DiagnosticStatus::WARN);
  EXPECT_EQ(msg->status[2].level, DiagnosticStatus::ERROR);
  EXPECT_EQ(msg->status[3].level, DiagnosticStatus::STALE);
  bool has_pos = false;
  bool has_vel = false;
  for (const auto & kv : msg->status[0].values) {
    has_pos |= kv.key == "position";
    has_vel |= kv.key == "velocity";
  }
  EXPECT_TRUE(has_pos && has_vel);
}
