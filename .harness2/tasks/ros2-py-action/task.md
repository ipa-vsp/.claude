Please write a ROS 2 (Lyrical) Python package `gripper_action` that simulates a parallel gripper
behind the standard `control_msgs/action/GripperCommand` action, so that we can test grasp
pipelines without hardware. Put it in the colcon workspace at `output/ws/src/gripper_action/`
(ament_python).

Domain layer, in `gripper_action/domain.py`, pure Python with no `rclpy` or `*_msgs` imports:

- `SimulatedGripper(max_opening: float, speed: float, object_width: float | None = None)`. It
  starts fully open (`position == max_opening`). Invalid arguments (`max_opening <= 0`,
  `speed <= 0`) raise `ValueError`.
- `step(target: float, dt: float) -> GripperState` moves toward `target` by at most `speed * dt`.
  If an object is present and the gripper closes onto it (target < object_width), it stops at
  `object_width` and reports `stalled=True`.
- `GripperState` is a frozen dataclass with `position: float`, `stalled: bool` and `reached: bool`,
  where `reached` means |position - target| < 1e-4.

ROS adapter:

- Console script `gripper_action_server`, node name `gripper_action_server`, serving the action
  `/gripper/gripper_cmd`.
- Declared parameters: `max_opening` (0.08), `speed` (0.05 m/s), `object_width` (0.0, meaning no
  object) and `update_rate_hz` (50.0).
- Reject goals whose `command.position` is outside `[0, max_opening]`. While executing, publish
  feedback every control step. Support cancellation. Return a result with the final
  `position`/`stalled`/`reached_goal`, and `effort = command.max_effort` when stalled.
- Use a callback group and executor setup in which cancellation and feedback actually work while a
  goal is running.
- `launch/gripper.launch.py` starts the server. It's installed to the package share.

Tests: pytest unit tests for the domain, and a `launch_testing` test that sends a goal through the
real action server. Both must pass with `colcon test`, and nothing may use sleeps to
synchronise.

Build from `output/ws`, and remove `build/`, `install/` and `log/` when you're done.
