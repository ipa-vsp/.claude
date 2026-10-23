We need a ROS 2 (Lyrical) driver package for a simulated 1-D range sensor. There's no real
hardware: generate readings in software. Please create the ament_cmake package
`range_sensor_driver` in the colcon workspace at `output/ws/src/range_sensor_driver/`.

- A managed (lifecycle) node, class `range_sensor_driver::RangeSensorNode`, declared in
  `include/range_sensor_driver/range_sensor_node.hpp`, with the constructor
  `explicit RangeSensorNode(const rclcpp::NodeOptions & options = rclcpp::NodeOptions())`.
  The default node name is `range_sensor`. Also register it as an rclcpp component.
- Declared parameters: `frame_id` (string, default `"range_link"`), `rate_hz` (double, default
  `20.0`), `min_range` (double, default `0.05`) and `max_range` (double, default `4.0`).
  `on_configure` must fail (return FAILURE) if `rate_hz <= 0` or `min_range >= max_range`.
- While active, publish `sensor_msgs/msg/Range` on `~/range` at `rate_hz` with sensor-data QoS.
  `header.frame_id = frame_id`, `min_range`/`max_range` are filled in, and `range` stays within
  them. Publish nothing unless active.
- Clean Architecture: the reading simulation and the filtering live in a pure C++ domain layer under
  `include/range_sensor_driver/domain/`, with no rclcpp and no `*_msgs` includes. The node is
  only an adapter.
- Export the library as the CMake target `range_sensor_driver::range_sensor_driver` (via
  `ament_export_targets`), so another package can `find_package(range_sensor_driver)` and link it.
  Use modern CMake and don't use the deprecated `ament_target_dependencies`.
- Tests: GTest for the domain layer, plus a node test that drives the lifecycle transitions.
  `colcon test` must pass. Don't use sleeps for synchronisation.
- A launch file `launch/range_sensor.launch.py`.

Build from the workspace root, `output/ws`. Remove `build/`, `install/` and `log/` from `output/ws`
when you're done.
