#!/usr/bin/env bash
# Hidden acceptance check for r2c-mock-hardware. cwd = workspace; colcon ws in output/ws.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
PKG=output/ws/src/twojoint_hardware
[ -f "$PKG/package.xml" ] || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "package missing"}'; exit 1; }
set +u; source /opt/ros/lyrical/setup.bash
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100)) ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
B="$(mktemp -d)"
C=(colcon --log-base "$B/log")
P=(--build-base "$B/build" --install-base "$B/install")
LINT="cppcheck|xmllint|uncrustify|cpplint|lint_cmake|flake8|pep257|copyright|linter"
cd output/ws
ac "colcon build (-Wall -Wextra -Werror=deprecated-declarations)" "${C[@]}" build "${P[@]}" --base-paths src --packages-select twojoint_hardware --cmake-args -DCMAKE_CXX_FLAGS='-Wall -Wextra -Werror=deprecated-declarations'
ac "own colcon tests pass" "${C[@]}" test "${P[@]}" --base-paths src --packages-select twojoint_hardware --return-code-on-test-failure --ctest-args -LE "$LINT"
ac "own tests use ResourceManager" bash -c "grep -rqE 'ResourceManager' src/twojoint_hardware/test"
ac "hidden ResourceManager tests build" "${C[@]}" build "${P[@]}" --base-paths src "$CHECK/hidden_pkgs" --packages-select twojoint_acceptance
ac "hidden behaviour tests pass" "${C[@]}" test "${P[@]}" --base-paths src "$CHECK/hidden_pkgs" --packages-select twojoint_acceptance --return-code-on-test-failure --event-handlers console_cohesion+
ac "pluginlib export declared" bash -c "grep -rq 'twojoint_hardware::TwoJointSystem' src/twojoint_hardware/*.xml && grep -q 'pluginlib_export_plugin_description_file' src/twojoint_hardware/CMakeLists.txt"
ac "no deprecated API / ament_target_dependencies" absent 'ament_target_dependencies|on_init\(const hardware_interface::HardwareInfo|export_state_interfaces\(\)|export_command_interfaces\(\)' src/twojoint_hardware
ac "xacro expands with both joints" bash -c "out=\$(xacro src/twojoint_hardware/description/twojoint.urdf.xacro) && echo \"\$out\" | grep -q 'name=\"joint1\"' && echo \"\$out\" | grep -q 'name=\"joint2\"' && echo \"\$out\" | grep -q 'twojoint_hardware/TwoJointSystem'"
ac "controllers.yaml defines both controllers" bash -c "python3 -c \"import yaml,sys; d=yaml.safe_load(open('src/twojoint_hardware/config/controllers.yaml')); s=str(d); sys.exit(0 if 'joint_state_broadcaster' in s and 'position_controller' in s and 'forward_command_controller' in s else 1)\""
rm -rf "$B"
ac_done
