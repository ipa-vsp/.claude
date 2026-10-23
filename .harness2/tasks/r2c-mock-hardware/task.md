Before the real arm arrives we want to bring up our ros2_control stack against a simulated 2-joint
system. Please write a hardware plugin package `twojoint_hardware` for **ROS 2 Lyrical /
ros2_control (Lyrical)** in the workspace at `output/ws/src/twojoint_hardware/`.

- Plugin class `twojoint_hardware::TwoJointSystem` (a `hardware_interface::SystemInterface`),
  exported with pluginlib as `twojoint_hardware/TwoJointSystem`.
- Joints come from the `<ros2_control>` tag. Each joint has a `position` command interface and
  `position` + `velocity` state interfaces. Reject (on init) any joint that doesn't have exactly
  this layout.
- Hardware parameter `time_constant` (seconds, required, > 0). Each `read()` moves the simulated
  position toward the commanded position as a first-order lag, and sets velocity to the resulting
  rate. Invalid or missing `time_constant` fails initialisation.
- Respect `initial_value` on the position state interface (default 0). On activation, initialise
  the commands to the current positions so the arm never jumps. Treat NaN commands as "hold
  position".
- Use the **current** Lyrical hardware-interface API: framework-managed interfaces
  (`set_state`/`get_state`/`set_command`/`get_command`) and the `on_init` overload that is not
  deprecated. The package must compile with `-Werror=deprecated-declarations`. Keep the lag model
  in a small ROS-free domain class.
- Also provide `description/twojoint.urdf.xacro` (joints `joint1` and `joint2`, plus the ros2_control
  tag), `config/controllers.yaml` (`joint_state_broadcaster` and a `forward_command_controller`
  named `position_controller` on the position interfaces), and `launch/twojoint.launch.py`
  (robot_state_publisher, ros2_control_node, and spawners).
- GTest tests that load the plugin through `hardware_interface::ResourceManager` with a URDF string.
  `colcon test` must pass.
- Modern CMake. No `ament_target_dependencies`.

Build from `output/ws`, and remove `build/`, `install/` and `log/` when you're done. Don't touch
real hardware.
