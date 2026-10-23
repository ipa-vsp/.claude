#!/usr/bin/env bash
# Hidden acceptance check for ros2-lifecycle-cpp. cwd = workspace; colcon ws in output/ws.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
PKG=output/ws/src/range_sensor_driver
[ -f "$PKG/package.xml" ] || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "package missing"}'; exit 1; }
set +u; source /opt/ros/lyrical/setup.bash
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100)) ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
B="$(mktemp -d)"
COLCON=(colcon --log-base "$B/log")
BUILD_ARGS=(--build-base "$B/build" --install-base "$B/install" --event-handlers console_cohesion+)
cd output/ws
ac "colcon build (-Wall -Wextra -Werror=deprecated-declarations)" "${COLCON[@]}" build "${BUILD_ARGS[@]}" --base-paths src --packages-select range_sensor_driver --cmake-args -DCMAKE_CXX_FLAGS='-Wall -Wextra -Werror=deprecated-declarations'
ac "own colcon tests pass" bash -c "'${COLCON[0]}' --log-base '$B/log' test --build-base '$B/build' --install-base '$B/install' --packages-select range_sensor_driver --return-code-on-test-failure --ctest-args -LE 'cppcheck|xmllint|uncrustify|cpplint|lint_cmake|flake8|pep257|copyright|linter'"
ac "own tests include gtest(s)" bash -c "grep -rlE 'ament_add_gtest|ament_add_gmock' src/range_sensor_driver/CMakeLists.txt"
ac "hidden package links exported target" "${COLCON[@]}" build "${BUILD_ARGS[@]}" --base-paths src "$CHECK/hidden_pkgs" --packages-select range_sensor_acceptance
ac "hidden lifecycle/publishing tests pass" bash -c "'${COLCON[0]}' --log-base '$B/log' test --build-base '$B/build' --install-base '$B/install' --base-paths src '$CHECK/hidden_pkgs' --packages-select range_sensor_acceptance --return-code-on-test-failure --event-handlers console_cohesion+"
ac "domain layer free of rclcpp/msgs" bash -c "[ -d src/range_sensor_driver/include/range_sensor_driver/domain ] && ! grep -rnE '#include *[<\"](rclcpp|rclcpp_lifecycle|[a-z_]+_msgs)/' src/range_sensor_driver/include/range_sensor_driver/domain"
ac "no ament_target_dependencies" absent 'ament_target_dependencies' src/range_sensor_driver/CMakeLists.txt
ac "launch file present" test -f src/range_sensor_driver/launch/range_sensor.launch.py
ac "registered as component" grep -q 'RCLCPP_COMPONENTS_REGISTER_NODE' -r src/range_sensor_driver/src
rm -rf "$B"
ac_done
