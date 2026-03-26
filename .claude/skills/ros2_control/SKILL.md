---
name: ROS2 Control
description: ros2_control framework - hardware interfaces, custom controllers, controller manager configuration, and URDF integration (C++)
---

# ROS2 Control Skill

This skill covers the `ros2_control` framework for real-time robot control. It provides patterns for writing hardware interfaces, custom controllers, URDF integration, configuration, and launch files following Clean Architecture principles.

## When to Activate

- User needs to interface with robot hardware (motors, sensors, actuators)
- User is writing a custom controller or hardware interface plugin
- User needs to configure the controller manager or spawn controllers
- User is adding `<ros2_control>` tags to a URDF/xacro
- User wants to use standard controllers (JointTrajectoryController, DiffDrive, etc.)
- User needs mock hardware for testing without physical devices

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                  Controller Manager                      │
│        (Lifecycle management, RT control loop)           │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Controller A │  │ Controller B │  │ Broadcaster  │    │
│  │  (update())  │  │  (update())  │  │  (update())  │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │ command_interfaces  state_interfaces│           │
│  ┌──────▼──────────────────────────────────▼──────┐     │
│  │              Resource Manager                    │     │
│  │   (Loads hardware plugins, manages interfaces)   │     │
│  └──────┬──────────────────────────────────┬──────┘     │
└─────────┼──────────────────────────────────┼────────────┘
          │                                  │
   ┌──────▼──────┐  ┌──────────┐  ┌────────▼──────┐
   │   System    │  │ Actuator │  │    Sensor     │
   │ (read/write)│  │ (read/write) │  (read only)  │
   └─────────────┘  └──────────┘  └───────────────┘
          │                                  │
      Hardware                           Hardware
```

**Control loop**: `RM::read()` -> all active `Controller::update()` -> `RM::write()`

## Hardware Component Types

| Type       | Purpose                              | Capabilities   | Example                  |
| ---------- | ------------------------------------ | -------------- | ------------------------ |
| **System** | Complex multi-DOF hardware           | Read + Write   | Robot arm, mobile base   |
| **Actuator** | Simple single-DOF actuator         | Read + Write   | Motor, valve, gripper    |
| **Sensor** | Sensing-only hardware                | Read only      | FT sensor, encoder, IMU  |

## Directory Structure (Clean Architecture)

```
src/
├── domain/
│   ├── entities/
│   │   └── joint_state.hpp          # Pure joint data
│   └── interfaces/
│       └── hardware_adapter.hpp     # Abstract hardware port
├── application/
│   └── use_cases/
│       └── compute_control.hpp      # Control logic (no ROS2)
└── infrastructure/
    └── ros2_control/
        ├── hardware/
        │   ├── my_robot_system.hpp
        │   ├── my_robot_system.cpp
        │   └── my_robot_system.xml   # Plugin descriptor
        ├── controllers/
        │   ├── my_controller.hpp
        │   ├── my_controller.cpp
        │   └── my_controller.xml
        └── config/
            └── controllers.yaml
```

## Writing a Hardware Interface (C++)

### Header

```cpp
// infrastructure/ros2_control/hardware/my_robot_system.hpp
#pragma once

#include <hardware_interface/system_interface.hpp>
#include <rclcpp_lifecycle/node_interfaces/lifecycle_node_interface.hpp>
#include <rclcpp/macros.hpp>
#include <vector>
#include <string>

namespace infrastructure::ros2_control {

using CallbackReturn = rclcpp_lifecycle::node_interfaces::LifecycleNodeInterface::CallbackReturn;

class MyRobotSystem : public hardware_interface::SystemInterface {
public:
    RCLCPP_SHARED_PTR_DEFINITIONS(MyRobotSystem)

    // Lifecycle callbacks
    CallbackReturn on_init(const hardware_interface::HardwareInfo & info) override;
    CallbackReturn on_configure(const rclcpp_lifecycle::State & previous_state) override;
    CallbackReturn on_activate(const rclcpp_lifecycle::State & previous_state) override;
    CallbackReturn on_deactivate(const rclcpp_lifecycle::State & previous_state) override;
    CallbackReturn on_cleanup(const rclcpp_lifecycle::State & previous_state) override;
    CallbackReturn on_shutdown(const rclcpp_lifecycle::State & previous_state) override;
    CallbackReturn on_error(const rclcpp_lifecycle::State & previous_state) override;

    // Real-time loop (must be RT-safe: no allocation, no blocking)
    hardware_interface::return_type read(
        const rclcpp::Time & time, const rclcpp::Duration & period) override;
    hardware_interface::return_type write(
        const rclcpp::Time & time, const rclcpp::Duration & period) override;

private:
    // State storage (populated by read(), consumed by controllers)
    std::vector<double> hw_positions_;
    std::vector<double> hw_velocities_;

    // Command storage (populated by controllers, sent by write())
    std::vector<double> hw_commands_;

    // Hardware parameters
    std::string serial_port_;
    int baud_rate_;
};

}  // namespace infrastructure::ros2_control
```

### Implementation

```cpp
// infrastructure/ros2_control/hardware/my_robot_system.cpp
#include "infrastructure/ros2_control/hardware/my_robot_system.hpp"
#include <pluginlib/class_list_macros.hpp>
#include <hardware_interface/types/hardware_interface_type_values.hpp>

namespace infrastructure::ros2_control {

CallbackReturn MyRobotSystem::on_init(const hardware_interface::HardwareInfo & info) {
    if (SystemInterface::on_init(info) != CallbackReturn::SUCCESS) {
        return CallbackReturn::ERROR;
    }

    // Parse hardware parameters from URDF <param> tags
    serial_port_ = info_.hardware_parameters["serial_port"];
    baud_rate_ = std::stoi(info_.hardware_parameters["baud_rate"]);

    // Validate joint configuration
    for (const auto & joint : info_.joints) {
        // Expect position command interface
        if (joint.command_interfaces.size() != 1 ||
            joint.command_interfaces[0].name != hardware_interface::HW_IF_POSITION) {
            RCLCPP_ERROR(rclcpp::get_logger("MyRobotSystem"),
                "Joint '%s' must have exactly one position command interface", joint.name.c_str());
            return CallbackReturn::ERROR;
        }
    }

    // Initialize state/command vectors
    hw_positions_.resize(info_.joints.size(), 0.0);
    hw_velocities_.resize(info_.joints.size(), 0.0);
    hw_commands_.resize(info_.joints.size(), 0.0);

    return CallbackReturn::SUCCESS;
}

CallbackReturn MyRobotSystem::on_configure(const rclcpp_lifecycle::State &) {
    // Establish communication with hardware
    // e.g., open serial port, connect to CAN bus
    RCLCPP_INFO(rclcpp::get_logger("MyRobotSystem"),
        "Connecting to %s at %d baud", serial_port_.c_str(), baud_rate_);
    return CallbackReturn::SUCCESS;
}

CallbackReturn MyRobotSystem::on_activate(const rclcpp_lifecycle::State &) {
    // Enable motor power, disengage brakes
    // Set commands to current positions to avoid jumps
    hw_commands_ = hw_positions_;
    return CallbackReturn::SUCCESS;
}

CallbackReturn MyRobotSystem::on_deactivate(const rclcpp_lifecycle::State &) {
    // Engage brakes, disable power
    return CallbackReturn::SUCCESS;
}

CallbackReturn MyRobotSystem::on_cleanup(const rclcpp_lifecycle::State &) {
    // Close hardware communication
    return CallbackReturn::SUCCESS;
}

CallbackReturn MyRobotSystem::on_shutdown(const rclcpp_lifecycle::State &) {
    // Emergency shutdown
    return CallbackReturn::SUCCESS;
}

CallbackReturn MyRobotSystem::on_error(const rclcpp_lifecycle::State &) {
    // Attempt error recovery
    // Return SUCCESS to go to UNCONFIGURED, ERROR to go to FINALIZED
    return CallbackReturn::SUCCESS;
}

hardware_interface::return_type MyRobotSystem::read(
    const rclcpp::Time &, const rclcpp::Duration &) {
    // Read encoder/sensor data from hardware into state vectors
    // These are accessed by controllers via state_interfaces
    // MUST be real-time safe
    return hardware_interface::return_type::OK;
}

hardware_interface::return_type MyRobotSystem::write(
    const rclcpp::Time &, const rclcpp::Duration &) {
    // Write command vectors to hardware
    // These were set by controllers via command_interfaces
    // MUST be real-time safe
    return hardware_interface::return_type::OK;
}

}  // namespace infrastructure::ros2_control

PLUGINLIB_EXPORT_CLASS(
    infrastructure::ros2_control::MyRobotSystem,
    hardware_interface::SystemInterface)
```

### Sensor-Only Hardware Interface

```cpp
// infrastructure/ros2_control/hardware/ft_sensor.hpp
#pragma once

#include <hardware_interface/sensor_interface.hpp>

namespace infrastructure::ros2_control {

class FTSensorHardware : public hardware_interface::SensorInterface {
public:
    CallbackReturn on_init(const hardware_interface::HardwareInfo & info) override;
    CallbackReturn on_configure(const rclcpp_lifecycle::State &) override;

    hardware_interface::return_type read(
        const rclcpp::Time & time, const rclcpp::Duration & period) override;

private:
    std::array<double, 6> ft_values_{};  // fx, fy, fz, tx, ty, tz
};

}  // namespace infrastructure::ros2_control
```

### Actuator Hardware Interface

```cpp
// infrastructure/ros2_control/hardware/gripper_actuator.hpp
#pragma once

#include <hardware_interface/actuator_interface.hpp>

namespace infrastructure::ros2_control {

class GripperActuator : public hardware_interface::ActuatorInterface {
public:
    CallbackReturn on_init(const hardware_interface::HardwareInfo & info) override;
    CallbackReturn on_configure(const rclcpp_lifecycle::State &) override;
    CallbackReturn on_activate(const rclcpp_lifecycle::State &) override;

    hardware_interface::return_type read(
        const rclcpp::Time & time, const rclcpp::Duration & period) override;
    hardware_interface::return_type write(
        const rclcpp::Time & time, const rclcpp::Duration & period) override;

private:
    double position_{0.0};
    double velocity_{0.0};
    double command_{0.0};
};

}  // namespace infrastructure::ros2_control
```

## Plugin Descriptor XML

```xml
<!-- infrastructure/ros2_control/hardware/my_robot_hardware.xml -->
<library format="2">
  <class name="my_robot_hardware/MyRobotSystem"
         type="infrastructure::ros2_control::MyRobotSystem"
         base_class_type="hardware_interface::SystemInterface">
    <description>Hardware interface for my robot arm</description>
  </class>

  <class name="my_robot_hardware/FTSensorHardware"
         type="infrastructure::ros2_control::FTSensorHardware"
         base_class_type="hardware_interface::SensorInterface">
    <description>Force-torque sensor hardware interface</description>
  </class>

  <class name="my_robot_hardware/GripperActuator"
         type="infrastructure::ros2_control::GripperActuator"
         base_class_type="hardware_interface::ActuatorInterface">
    <description>Gripper actuator hardware interface</description>
  </class>
</library>
```

## Writing a Custom Controller (C++)

### Header

```cpp
// infrastructure/ros2_control/controllers/my_controller.hpp
#pragma once

#include <controller_interface/controller_interface.hpp>
#include <rclcpp_lifecycle/node_interfaces/lifecycle_node_interface.hpp>
#include <realtime_tools/realtime_buffer.hpp>
#include <std_msgs/msg/float64_multi_array.hpp>

namespace infrastructure::ros2_control {

class MyController : public controller_interface::ControllerInterface {
public:
    controller_interface::InterfaceConfiguration
        command_interface_configuration() const override;
    controller_interface::InterfaceConfiguration
        state_interface_configuration() const override;

    controller_interface::CallbackReturn on_init() override;
    controller_interface::CallbackReturn on_configure(
        const rclcpp_lifecycle::State & previous_state) override;
    controller_interface::CallbackReturn on_activate(
        const rclcpp_lifecycle::State & previous_state) override;
    controller_interface::CallbackReturn on_deactivate(
        const rclcpp_lifecycle::State & previous_state) override;

    // Called every control cycle - MUST be real-time safe
    controller_interface::return_type update(
        const rclcpp::Time & time, const rclcpp::Duration & period) override;

private:
    std::vector<std::string> joint_names_;
    std::string interface_name_;

    // Real-time safe subscriber buffer
    realtime_tools::RealtimeBuffer<std::shared_ptr<std_msgs::msg::Float64MultiArray>> rt_command_ptr_;
    rclcpp::Subscription<std_msgs::msg::Float64MultiArray>::SharedPtr command_sub_;
};

}  // namespace infrastructure::ros2_control
```

### Implementation

```cpp
// infrastructure/ros2_control/controllers/my_controller.cpp
#include "infrastructure/ros2_control/controllers/my_controller.hpp"
#include <pluginlib/class_list_macros.hpp>

namespace infrastructure::ros2_control {

controller_interface::CallbackReturn MyController::on_init() {
    // Declare parameters (read from YAML)
    auto_declare<std::vector<std::string>>("joints", std::vector<std::string>());
    auto_declare<std::string>("interface_name", "position");
    return controller_interface::CallbackReturn::SUCCESS;
}

controller_interface::CallbackReturn MyController::on_configure(
    const rclcpp_lifecycle::State &) {
    joint_names_ = get_node()->get_parameter("joints").as_string_array();
    interface_name_ = get_node()->get_parameter("interface_name").as_string();

    if (joint_names_.empty()) {
        RCLCPP_ERROR(get_node()->get_logger(), "'joints' parameter is empty");
        return controller_interface::CallbackReturn::ERROR;
    }

    // Create subscription (non-RT thread)
    command_sub_ = get_node()->create_subscription<std_msgs::msg::Float64MultiArray>(
        "~/commands", 10,
        [this](const std_msgs::msg::Float64MultiArray::SharedPtr msg) {
            rt_command_ptr_.writeFromNonRT(msg);
        });

    return controller_interface::CallbackReturn::SUCCESS;
}

controller_interface::InterfaceConfiguration
MyController::command_interface_configuration() const {
    controller_interface::InterfaceConfiguration config;
    config.type = controller_interface::interface_configuration_type::INDIVIDUAL;
    for (const auto & joint : joint_names_) {
        config.names.push_back(joint + "/" + interface_name_);
    }
    return config;
}

controller_interface::InterfaceConfiguration
MyController::state_interface_configuration() const {
    controller_interface::InterfaceConfiguration config;
    config.type = controller_interface::interface_configuration_type::INDIVIDUAL;
    for (const auto & joint : joint_names_) {
        config.names.push_back(joint + "/position");
        config.names.push_back(joint + "/velocity");
    }
    return config;
}

controller_interface::CallbackReturn MyController::on_activate(
    const rclcpp_lifecycle::State &) {
    // Verify interfaces are available
    return controller_interface::CallbackReturn::SUCCESS;
}

controller_interface::CallbackReturn MyController::on_deactivate(
    const rclcpp_lifecycle::State &) {
    return controller_interface::CallbackReturn::SUCCESS;
}

controller_interface::return_type MyController::update(
    const rclcpp::Time &, const rclcpp::Duration &) {
    // REAL-TIME SAFE: no allocation, no blocking, no logging
    auto msg = rt_command_ptr_.readFromRT();
    if (!msg || !(*msg)) {
        return controller_interface::return_type::OK;
    }

    for (size_t i = 0; i < command_interfaces_.size(); ++i) {
        command_interfaces_[i].set_value((*msg)->data[i]);
    }

    return controller_interface::return_type::OK;
}

}  // namespace infrastructure::ros2_control

PLUGINLIB_EXPORT_CLASS(
    infrastructure::ros2_control::MyController,
    controller_interface::ControllerInterface)
```

### Controller Plugin XML

```xml
<!-- infrastructure/ros2_control/controllers/my_controller.xml -->
<library format="2">
  <class name="my_package/MyController"
         type="infrastructure::ros2_control::MyController"
         base_class_type="controller_interface::ControllerInterface">
    <description>Custom controller for my robot</description>
  </class>
</library>
```

## URDF ros2_control Tags

### System (Multi-DOF Robot)

```xml
<ros2_control name="MyRobotSystem" type="system">
  <hardware>
    <plugin>my_robot_hardware/MyRobotSystem</plugin>
    <param name="serial_port">/dev/ttyUSB0</param>
    <param name="baud_rate">115200</param>
  </hardware>
  <joint name="joint1">
    <command_interface name="position">
      <param name="min">-3.14</param>
      <param name="max">3.14</param>
    </command_interface>
    <state_interface name="position"/>
    <state_interface name="velocity"/>
  </joint>
  <joint name="joint2">
    <command_interface name="position"/>
    <command_interface name="velocity"/>
    <state_interface name="position"/>
    <state_interface name="velocity"/>
  </joint>
</ros2_control>
```

### Sensor

```xml
<ros2_control name="FTSensor" type="sensor">
  <hardware>
    <plugin>my_robot_hardware/FTSensorHardware</plugin>
  </hardware>
  <sensor name="tcp_fts_sensor">
    <state_interface name="force.x"/>
    <state_interface name="force.y"/>
    <state_interface name="force.z"/>
    <state_interface name="torque.x"/>
    <state_interface name="torque.y"/>
    <state_interface name="torque.z"/>
    <param name="frame_id">tool0</param>
  </sensor>
</ros2_control>
```

### Actuator (Modular)

```xml
<ros2_control name="Gripper" type="actuator">
  <hardware>
    <plugin>my_robot_hardware/GripperActuator</plugin>
  </hardware>
  <joint name="gripper_joint">
    <command_interface name="position">
      <param name="min">0.0</param>
      <param name="max">0.08</param>
    </command_interface>
    <state_interface name="position"/>
    <state_interface name="velocity"/>
  </joint>
</ros2_control>
```

### GPIO Interfaces

```xml
<gpio name="tool_io">
  <command_interface name="digital_output_1"/>
  <command_interface name="digital_output_2"/>
  <state_interface name="digital_input_1"/>
  <state_interface name="analog_input_1"/>
</gpio>
```

### Mock Components (Testing)

```xml
<ros2_control name="MockRobot" type="system">
  <hardware>
    <plugin>mock_components/GenericSystem</plugin>
    <param name="calculate_dynamics">true</param>
    <param name="mock_sensor_commands">true</param>
  </hardware>
  <joint name="joint1">
    <command_interface name="position"/>
    <state_interface name="position">
      <param name="initial_value">0.0</param>
    </state_interface>
    <state_interface name="velocity"/>
  </joint>
</ros2_control>
```

## Controller Manager Configuration (YAML)

```yaml
controller_manager:
  ros__parameters:
    update_rate: 100  # Hz

    # Declare controllers
    joint_state_broadcaster:
      type: joint_state_broadcaster/JointStateBroadcaster

    forward_position_controller:
      type: forward_command_controller/ForwardCommandController

    joint_trajectory_controller:
      type: joint_trajectory_controller/JointTrajectoryController

    diff_drive_controller:
      type: diff_drive_controller/DiffDriveController

    # Hardware initial state overrides
    hardware_components_initial_state:
      unconfigured:
        - "sensor_1"

# Controller-specific parameters
forward_position_controller:
  ros__parameters:
    joints:
      - joint1
      - joint2
    interface_name: position

joint_trajectory_controller:
  ros__parameters:
    joints:
      - joint1
      - joint2
    command_interfaces:
      - position
    state_interfaces:
      - position
      - velocity
    state_publish_rate: 50.0
    action_monitor_rate: 20.0

diff_drive_controller:
  ros__parameters:
    left_wheel_names: ["left_wheel_joint"]
    right_wheel_names: ["right_wheel_joint"]
    wheel_separation: 0.35
    wheel_radius: 0.05
    publish_rate: 50.0
    odom_frame_id: odom
    base_frame_id: base_link
```

## Launch File Pattern

```python
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, RegisterEventHandler
from launch.event_handlers import OnProcessExit
from launch.substitutions import Command, LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    # Robot description from xacro
    robot_description_content = Command([
        'xacro ',
        PathJoinSubstitution([
            FindPackageShare('my_robot_description'), 'urdf', 'robot.urdf.xacro'
        ])
    ])

    # Controller config
    robot_controllers = PathJoinSubstitution([
        FindPackageShare('my_robot_bringup'), 'config', 'controllers.yaml'
    ])

    # Controller Manager
    control_node = Node(
        package='controller_manager',
        executable='ros2_control_node',
        parameters=[robot_controllers],
        output='both',
        remappings=[
            ('~/robot_description', '/robot_description'),
        ],
    )

    # Robot State Publisher
    robot_state_pub = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        output='both',
        parameters=[{'robot_description': robot_description_content}],
    )

    # Spawn controllers (order matters)
    joint_state_broadcaster_spawner = Node(
        package='controller_manager',
        executable='spawner',
        arguments=['joint_state_broadcaster'],
    )

    position_controller_spawner = Node(
        package='controller_manager',
        executable='spawner',
        arguments=['forward_position_controller', '--param-file', robot_controllers],
    )

    # Chain: start motion controller after broadcaster is ready
    delay_controller = RegisterEventHandler(
        event_handler=OnProcessExit(
            target_action=joint_state_broadcaster_spawner,
            on_exit=[position_controller_spawner],
        )
    )

    return LaunchDescription([
        control_node,
        robot_state_pub,
        joint_state_broadcaster_spawner,
        delay_controller,
    ])
```

## CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.8)
project(my_robot_hardware)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(hardware_interface REQUIRED)
find_package(controller_interface REQUIRED)
find_package(pluginlib REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rclcpp_lifecycle REQUIRED)
find_package(realtime_tools REQUIRED)

# Hardware interface library
add_library(my_robot_hardware SHARED
  src/my_robot_system.cpp
  src/ft_sensor.cpp
  src/gripper_actuator.cpp
)
target_include_directories(my_robot_hardware PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
ament_target_dependencies(my_robot_hardware
  hardware_interface pluginlib rclcpp rclcpp_lifecycle)

# Custom controller library
add_library(my_controller SHARED
  src/my_controller.cpp
)
target_include_directories(my_controller PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
ament_target_dependencies(my_controller
  controller_interface pluginlib rclcpp rclcpp_lifecycle realtime_tools)

# Export plugins
pluginlib_export_plugin_description_file(hardware_interface my_robot_hardware.xml)
pluginlib_export_plugin_description_file(controller_interface my_controller.xml)

# Install
install(TARGETS my_robot_hardware my_controller
  LIBRARY DESTINATION lib)
install(DIRECTORY include/
  DESTINATION include)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
```

## Common Controllers Reference

| Controller                         | Type      | Use Case                              |
| ---------------------------------- | --------- | ------------------------------------- |
| `joint_state_broadcaster`          | Broadcast | Publish joint states to `/joint_states` |
| `forward_command_controller`       | Motion    | Direct position/velocity/effort commands |
| `joint_trajectory_controller`      | Motion    | Trajectory execution with interpolation |
| `diff_drive_controller`            | Mobile    | Differential drive base               |
| `mecanum_drive_controller`         | Mobile    | Mecanum wheel base                    |
| `ackermann_steering_controller`    | Mobile    | Ackermann steering vehicle            |
| `tricycle_controller`              | Mobile    | Tricycle kinematics                   |
| `pid_controller`                   | Motion    | Generic PID control loop              |
| `admittance_controller`            | Motion    | Force-based compliant control         |
| `parallel_gripper_controller`      | Motion    | Parallel jaw gripper                  |
| `force_torque_sensor_broadcaster`  | Broadcast | Publish FT sensor data                |
| `imu_sensor_broadcaster`           | Broadcast | Publish IMU data                      |
| `gpio_command_controller`          | I/O       | Control GPIO pins                     |

## CLI Commands

```bash
# List loaded controllers and their states
ros2 control list_controllers

# List available hardware interfaces
ros2 control list_hardware_interfaces

# List available controller/hardware plugins
ros2 control list_controller_types
ros2 control list_hardware_component_types

# Load, configure, activate controllers
ros2 control load_controller my_controller
ros2 control set_controller_state my_controller inactive
ros2 control set_controller_state my_controller active

# Switch controllers atomically
ros2 control switch_controllers --activate my_controller --deactivate old_controller --strict

# Spawn / unspawn (from launch or CLI)
ros2 run controller_manager spawner my_controller --param-file params.yaml
ros2 run controller_manager spawner my_controller --inactive
ros2 run controller_manager unspawner my_controller

# Hardware component lifecycle
ros2 run controller_manager hardware_spawner my_hw --activate
```

## Best Practices

- **Real-time safety**: `update()`, `read()`, and `write()` must never allocate memory, log, or block. Use `realtime_tools` for publishers and buffers.
- **Standard interface names**: Use `position`, `velocity`, `acceleration`, `effort` for joint interfaces to ensure compatibility with existing controllers.
- **Validate early**: Check all parameters and interface configurations in `on_init()` / `on_configure()` before activating.
- **Error recovery**: Implement `on_error()` in hardware interfaces. Return `SUCCESS` to recover to UNCONFIGURED, `ERROR` to go to FINALIZED.
- **Mock components**: Use `mock_components/GenericSystem` during development to test controller logic without physical hardware.
- **Spawner ordering**: Use `OnProcessExit` event handlers in launch files to ensure `joint_state_broadcaster` starts before motion controllers.
- **Command limits**: Keep `enforce_command_limits: true` (default) and define `min`/`max` in URDF `<command_interface>` tags.
- **Xacro for composability**: Always use xacro macros for `<ros2_control>` blocks to enable hardware swapping between real and mock.
- **Async controllers**: Use `is_async: true` with `thread_priority` and `cpu_affinity` for controllers that need their own update rate.
