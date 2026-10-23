#!/usr/bin/env bash
# Hidden acceptance check for ros2-py-action. cwd = workspace; colcon ws in output/ws.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
PKG=output/ws/src/gripper_action
[ -f "$PKG/package.xml" ] || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "package missing"}'; exit 1; }
set +u; source /opt/ros/lyrical/setup.bash
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100)) ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST PYTHONDONTWRITEBYTECODE=1
B="$(mktemp -d)"
cd output/ws
ac "colcon build" colcon --log-base "$B/log" build --build-base "$B/build" --install-base "$B/install" --packages-select gripper_action
ac "own colcon tests pass" colcon --log-base "$B/log" test --build-base "$B/build" --install-base "$B/install" --packages-select gripper_action --return-code-on-test-failure --pytest-args -p no:cacheprovider -k "not flake8 and not pep257 and not copyright and not xmllint"
ac "own launch_testing test present" bash -c "grep -rlqE 'launch_testing|launch_pytest' src/gripper_action/test"
source "$B/install/setup.bash"
ac "hidden domain tests pass" python3 -m pytest -q -p no:cacheprovider "$CHECK/test_hidden_domain.py"
ac "hidden action tests pass (launch_testing)" timeout 300 launch_test "$CHECK/test_hidden_launch.py"
ac "domain layer free of rclpy/msgs" bash -c "! grep -nE '^\s*(import|from)\s+(rclpy|[a-z_]+_msgs)' src/gripper_action/gripper_action/domain.py"
ac "flake8 E/W/F clean" python3 -m flake8 --select E,W,F --max-line-length 100 src/gripper_action/gripper_action
ac "no sleeps in package or tests" absent 'time\.sleep|sleep\(' src/gripper_action/gripper_action src/gripper_action/test
rm -rf "$B"
ac_done
