#include <gtest/gtest.h>

#include <chrono>
#include <future>
#include <memory>

#include <lifecycle_msgs/msg/state.hpp>
#include <lifecycle_msgs/msg/transition.hpp>
#include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/range.hpp>

#include "range_sensor_driver/range_sensor_node.hpp"

using lifecycle_msgs::msg::State;
using lifecycle_msgs::msg::Transition;
using namespace std::chrono_literals;

class RangeAcceptance : public ::testing::Test {
 protected:
  static void SetUpTestSuite() { rclcpp::init(0, nullptr); }
  static void TearDownTestSuite() { rclcpp::shutdown(); }
};

static std::shared_ptr<range_sensor_driver::RangeSensorNode> make(
  std::vector<rclcpp::Parameter> params)
{
  rclcpp::NodeOptions opts;
  opts.parameter_overrides(params);
  return std::make_shared<range_sensor_driver::RangeSensorNode>(opts);
}

TEST_F(RangeAcceptance, DefaultsAndName) {
  auto node = make({});
  EXPECT_EQ(std::string(node->get_name()), "range_sensor");
  EXPECT_EQ(node->get_parameter("frame_id").as_string(), "range_link");
  EXPECT_DOUBLE_EQ(node->get_parameter("rate_hz").as_double(), 20.0);
  EXPECT_DOUBLE_EQ(node->get_parameter("min_range").as_double(), 0.05);
  EXPECT_DOUBLE_EQ(node->get_parameter("max_range").as_double(), 4.0);
  EXPECT_EQ(node->get_current_state().id(), State::PRIMARY_STATE_UNCONFIGURED);
}

TEST_F(RangeAcceptance, RejectsBadRate) {
  auto node = make({rclcpp::Parameter("rate_hz", -1.0)});
  node->trigger_transition(Transition::TRANSITION_CONFIGURE);
  EXPECT_EQ(node->get_current_state().id(), State::PRIMARY_STATE_UNCONFIGURED);
}

TEST_F(RangeAcceptance, RejectsInvertedRange) {
  auto node = make({rclcpp::Parameter("min_range", 5.0), rclcpp::Parameter("max_range", 1.0)});
  node->trigger_transition(Transition::TRANSITION_CONFIGURE);
  EXPECT_EQ(node->get_current_state().id(), State::PRIMARY_STATE_UNCONFIGURED);
}

TEST_F(RangeAcceptance, PublishesOnlyWhenActive) {
  auto node = make({rclcpp::Parameter("frame_id", "tof_front"), rclcpp::Parameter("rate_hz", 50.0),
                    rclcpp::Parameter("min_range", 0.1), rclcpp::Parameter("max_range", 2.0)});
  auto probe = std::make_shared<rclcpp::Node>("range_probe");
  rclcpp::executors::SingleThreadedExecutor exec;
  exec.add_node(node->get_node_base_interface());
  exec.add_node(probe);

  int count = 0;
  sensor_msgs::msg::Range last;
  std::promise<void> got3;
  auto sub = probe->create_subscription<sensor_msgs::msg::Range>(
    "/range_sensor/range", rclcpp::SensorDataQoS(),
    [&](sensor_msgs::msg::Range::ConstSharedPtr msg) {
      last = *msg;
      if (++count == 3) { got3.set_value(); }
    });

  node->trigger_transition(Transition::TRANSITION_CONFIGURE);
  ASSERT_EQ(node->get_current_state().id(), State::PRIMARY_STATE_INACTIVE);
  exec.spin_all(300ms);
  EXPECT_EQ(count, 0) << "published while inactive";

  node->trigger_transition(Transition::TRANSITION_ACTIVATE);
  ASSERT_EQ(node->get_current_state().id(), State::PRIMARY_STATE_ACTIVE);
  auto fut = got3.get_future();
  ASSERT_EQ(exec.spin_until_future_complete(fut, 10s), rclcpp::FutureReturnCode::SUCCESS);
  EXPECT_EQ(last.header.frame_id, "tof_front");
  EXPECT_FLOAT_EQ(last.min_range, 0.1F);
  EXPECT_FLOAT_EQ(last.max_range, 2.0F);
  EXPECT_GE(last.range, 0.1F);
  EXPECT_LE(last.range, 2.0F);

  node->trigger_transition(Transition::TRANSITION_DEACTIVATE);
  EXPECT_EQ(node->get_current_state().id(), State::PRIMARY_STATE_INACTIVE);
  exec.spin_all(100ms);
  const int after = count;
  exec.spin_all(300ms);
  EXPECT_EQ(count, after) << "published after deactivate";
}
