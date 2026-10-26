---
name: ros2-lifecycle
description: ROS2 Managed (Lifecycle) Node implementation with Clean Architecture (Python & C++)
---

# ROS2 Lifecycle Nodes Skill

## Resource Ownership Across Transitions

- Declare parameters in construction; validate configuration and acquire
  resources during configure. A failed configure must release partially
  acquired resources and leave the node safe to configure again.
- Activate managed publishers and start work only after activation succeeds.
  Ordinary subscriptions, timers, and services are not automatically disabled
  by lifecycle state; cancel or gate them explicitly while inactive.
- Deactivate by stopping work before disabling publishers. Cleanup releases
  configured resources; shutdown handles both active and inactive states.
  Make cleanup safe after partial initialization and repeated transitions.
- In rclpy, preserve the lifecycle base callbacks' managed-entity behavior when
  overriding transitions, or explicitly perform equivalent management. Verify
  the installed API rather than assuming Python and C++ callbacks are identical.
- Test configure/activate/deactivate/cleanup/reconfigure, rejected configuration,
  and shutdown. Assert state and resource behavior using bounded executor waits.

## Lifecycle States

```
              +---------+
              | UNKNOWN |
              +----+----+
                   |
              create()
                   v
           +------+------+
           | UNCONFIGURED|<----+
           +------+------+     |
                  |            |
            configure()   cleanup()
                  v            |
           +------+------+     |
           |  INACTIVE  |------+
           +------+------+
                  |
            activate()
                  v
           +------+------+
           |   ACTIVE   |
           +------+------+
                  |
           deactivate()
                  v
           +------+------+
           |  INACTIVE  |
           +-------------+
```

## Python Implementation

Subclass `rclpy.lifecycle.LifecycleNode` and implement the required transition
callbacks with `TransitionCallbackReturn`. Create resources in configure and
release them in cleanup; preserve managed-entity activation through the base
callbacks. Keep timer and subscription activity explicitly tied to state.

## C++ Implementation

### Lifecycle Node Template

```cpp
// infrastructure/ros2/nodes/managed_node.hpp
#pragma once

#include <rclcpp/rclcpp.hpp>
#include <rclcpp_lifecycle/lifecycle_node.hpp>
#include <rclcpp_lifecycle/lifecycle_publisher.hpp>
#include <std_msgs/msg/string.hpp>

namespace infrastructure::ros2::nodes {

using CallbackReturn = rclcpp_lifecycle::node_interfaces::LifecycleNodeInterface::CallbackReturn;

class ManagedNode : public rclcpp_lifecycle::LifecycleNode {
public:
    explicit ManagedNode(const std::string& node_name, bool intra_process_comms = false)
        : rclcpp_lifecycle::LifecycleNode(node_name,
            rclcpp::NodeOptions().use_intra_process_comms(intra_process_comms)) {}

    CallbackReturn on_configure(const rclcpp_lifecycle::State &) override {
        RCLCPP_INFO(get_logger(), "Configuring...");
        pub_ = this->create_publisher<std_msgs::msg::String>("topic", 10);
        return CallbackReturn::SUCCESS;
    }

    CallbackReturn on_activate(const rclcpp_lifecycle::State &) override {
        RCLCPP_INFO(get_logger(), "Activating...");
        pub_->on_activate();
        // Start timers, etc.
        return CallbackReturn::SUCCESS;
    }

    CallbackReturn on_deactivate(const rclcpp_lifecycle::State &) override {
        RCLCPP_INFO(get_logger(), "Deactivating...");
        pub_->on_deactivate();
        return CallbackReturn::SUCCESS;
    }

    CallbackReturn on_cleanup(const rclcpp_lifecycle::State &) override {
        RCLCPP_INFO(get_logger(), "Cleaning up...");
        pub_.reset();
        return CallbackReturn::SUCCESS;
    }

    CallbackReturn on_shutdown(const rclcpp_lifecycle::State &) override {
        RCLCPP_INFO(get_logger(), "Shutting down...");
        return CallbackReturn::SUCCESS;
    }

private:
    rclcpp_lifecycle::LifecyclePublisher<std_msgs::msg::String>::SharedPtr pub_;
};

} // namespace
```

### Lifecycle Client (C++)

Allows controlling the state of another node using the `lifeycle_msgs` services.

```cpp
// infrastructure/ros2/lifecycle/lifecycle_client.hpp
#include <rclcpp/rclcpp.hpp>
#include <lifecycle_msgs/srv/change_state.hpp>
#include <lifecycle_msgs/srv/get_state.hpp>

class LifecycleClient {
public:
    LifecycleClient(rclcpp::Node::SharedPtr node, const std::string& target_node) {
        client_ = node->create_client<lifecycle_msgs::srv::ChangeState>(
            target_node + "/change_state");
    }

    bool change_state(std::uint8_t transition_id) {
        auto request = std::make_shared<lifecycle_msgs::srv::ChangeState::Request>();
        request->transition.id = transition_id;

        // ... async call logic ...
        return true;
    }

private:
    rclcpp::Client<lifecycle_msgs::srv::ChangeState>::SharedPtr client_;
};
```

## Best Practices

- **Resource Management**: Allocate resources (memory, connections) in `on_configure` and release them in `on_cleanup`.
- **Activity**: Only publish data or perform main logic when in the **ACTIVE** state.
- **Error Handling**: Use `on_error` callback to handle failures during transitions.
- **Launch Integration**: Use `LifecycleNode` in launch files to automatically manage states.
