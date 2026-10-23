We'd like a joint-health broadcaster for our arm on **ROS 2 Lyrical / ros2_control (Lyrical)**.
Please create the package `joint_health_broadcaster` in `output/ws/src/joint_health_broadcaster/`.

- Class `joint_health_broadcaster::JointHealthBroadcaster` (a `controller_interface::ControllerInterface`),
  in `include/joint_health_broadcaster/joint_health_broadcaster.hpp`, pluginlib name
  `joint_health_broadcaster/JointHealthBroadcaster`. Export the CMake target
  `joint_health_broadcaster::joint_health_broadcaster`.
- Parameters: `joints` (string array, non-empty), `velocity_warn` (double, default 1.0) and
  `velocity_error` (double, default 2.0). Configure fails unless `0 < velocity_warn < velocity_error`.
- Claims the state interfaces `<joint>/position` and `<joint>/velocity` and no command interfaces.
- Every `update()` publishes a `diagnostic_msgs/msg/DiagnosticArray` on `~/health` from the
  real-time loop, without blocking, using the current (non-deprecated) `realtime_tools` API. It
  has one status per joint, in parameter order:
  - `name` is the joint name.
  - `level` is `OK`; `WARN` if |velocity| >= velocity_warn; `ERROR` if |velocity| >=
    velocity_error; `STALE` if a value can't be read or is NaN.
  - `values` holds the key/value pairs `position` and `velocity`.
- It must build with `-Werror=deprecated-declarations`, use modern CMake and no
  `ament_target_dependencies`, and include GTest tests. `colcon test` must pass.

Build from `output/ws`, and remove `build/`, `install/` and `log/` when you're done.
