#!/usr/bin/env bash
# Hidden acceptance check for r2c-broadcaster. cwd = workspace; colcon ws in output/ws.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
PKG=output/ws/src/joint_health_broadcaster
[ -f "$PKG/package.xml" ] || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "package missing"}'; exit 1; }
set +u; source /opt/ros/lyrical/setup.bash
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100)) ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
B="$(mktemp -d)"
C=(colcon --log-base "$B/log")
P=(--build-base "$B/build" --install-base "$B/install")
LINT="cppcheck|xmllint|uncrustify|cpplint|lint_cmake|flake8|pep257|copyright|linter"
cd output/ws
ac "colcon build (-Wall -Wextra -Werror=deprecated-declarations)" "${C[@]}" build "${P[@]}" --base-paths src --packages-select joint_health_broadcaster --cmake-args -DCMAKE_CXX_FLAGS='-Wall -Wextra -Werror=deprecated-declarations'
ac "own colcon tests pass" "${C[@]}" test "${P[@]}" --base-paths src --packages-select joint_health_broadcaster --return-code-on-test-failure --ctest-args -LE "$LINT"
ac "hidden tests build against exported target" "${C[@]}" build "${P[@]}" --base-paths src "$CHECK/hidden_pkgs" --packages-select health_acceptance
ac "hidden broadcaster tests pass" "${C[@]}" test "${P[@]}" --base-paths src "$CHECK/hidden_pkgs" --packages-select health_acceptance --return-code-on-test-failure --event-handlers console_cohesion+
ac "no deprecated realtime/CMake APIs" absent 'ament_target_dependencies|RealtimeBuffer|trylock\(|unlockAndPublish' src/joint_health_broadcaster
rm -rf "$B"
ac_done
