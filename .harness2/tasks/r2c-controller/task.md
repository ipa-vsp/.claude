We want a safety-clamped version of `forward_command_controller` for **ROS 2 Lyrical /
ros2_control (Lyrical)**. Please create the package `clamp_forward_controller` in
`output/ws/src/clamp_forward_controller/`.

- Class `clamp_forward_controller::ClampForwardController` (a `controller_interface::ControllerInterface`),
  declared in `include/clamp_forward_controller/clamp_forward_controller.hpp`, exported with pluginlib
  as `clamp_forward_controller/ClampForwardController`. Also export the library as the CMake target
  `clamp_forward_controller::clamp_forward_controller` (`ament_export_targets`).
- Parameters via `generate_parameter_library`:
  - `joints` (string array, non-empty, unique)
  - `interface_name` (string, default `"position"`)
  - `lower_limits`, `upper_limits` (double arrays)
  `on_configure` fails if the limit arrays don't match `joints` in length, or if any
  `lower >= upper`.
- Claims exactly the command interfaces `<joint>/<interface_name>` and no state interfaces.
- Subscribes to `~/commands` (`std_msgs/msg/Float64MultiArray`). The handoff from the subscriber
  to `update()` must be real-time safe, so no blocking locks in `update()`. Use the current
  realtime_tools API, not deprecated classes.
- In `update()`, apply the latest command clamped into `[lower, upper]` per joint. Ignore messages
  whose size doesn't match the number of joints, with a throttled warning. Skip NaN entries, so
  that joint keeps its previous command. After activation, write nothing until a fresh message
  arrives, so a stale command from before deactivation is never replayed.
- Use the current controller API (`init(const ControllerInterfaceParams &)`, `get_optional` /
  `set_value` returning bool). It must build with `-Werror=deprecated-declarations`.
- GTest tests that exercise the controller directly. `colcon test` must pass.
- Modern CMake. No `ament_target_dependencies`.

Build from `output/ws`, and remove `build/`, `install/` and `log/` when you're done.
