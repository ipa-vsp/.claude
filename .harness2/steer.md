# Improver steering: skills lab (C++ / Python / Rust / ROS 2 Lyrical / ros2_control)

## Scope (hard rules)

- Edit only `.agents/skills/**`. Change `AGENTS.md` only to add or adjust a row in a skill index
  table. Don't rewrite its other sections.
- Never create, edit or delete `rea-wiki-vault` or `harness2-setup`. They are deliberately absent
  from the lab.
- Keep every skill's frontmatter `name` unchanged. A `description` may be sharpened, but it must
  keep stating when to use the skill.
- Prefer fixing or extending an existing skill over creating a new one. Create a new skill only for
  a recurring gap that no existing skill owns, such as ament_python packaging if no ROS skill covers
  it.
- Keep skills reference-shaped: rules, a short correct example, and a checklist. Don't paste whole
  task solutions or anything specific to a single task.

## Target platform

- ROS 2 **Lyrical Luth** (LTS, May 2026) at `/opt/ros/lyrical`, with ros2_control and
  ros2_controllers (Lyrical). There is also g++ 15 (C++20), Python 3.14, Rust 1.99 / edition 2024,
  clang-tidy 21, GoogleTest, pytest + pytest-cov, mypy and flake8.
- Examples in skills must compile on this platform without deprecation warnings.

## Known gaps found by the pre-run audit (verified against installed Lyrical headers)

### ros2-control (largest gap)

- `on_init(const hardware_interface::HardwareInfo &)` is **removed** in Lyrical. Use
  `on_init(const hardware_interface::HardwareComponentInterfaceParams & params)`, call the base
  class first, then read `get_hardware_info()` (or `params.hardware_info`).
- `export_state_interfaces()` / `export_command_interfaces()` returning vectors are deprecated or
  removed. The framework now owns the interface storage, through
  `set_state/get_state/set_command/get_command("<joint>/<iface>")`. Unlisted interfaces go through
  `export_unlisted_*_interface_descriptions()`.
- Loaned interfaces: `get_optional<T>()` returns `std::optional<T>`, and `set_value(v)` returns a
  `[[nodiscard]] bool` and throws on a type mismatch (`set_value(0)` on a double interface throws;
  use `0.0`). The `Handle(prefix, name, double*)` constructor and `operator bool` are removed.
- Controllers: `init(const controller_interface::ControllerInterfaceParams &)` replaces the
  positional `init(...)`. Chainable controllers use `on_export_state_interfaces_list()` /
  `on_export_reference_interfaces_list()`.
- `realtime_tools::RealtimeBuffer` is deprecated. Use `RealtimeThreadSafeBox`
  (`set/try_set/get/try_get`). `RealtimePublisher` is now constructed from
  `(node, topic, qos)` and published with `try_publish(msg)`; `trylock()`, `msg_` and
  `unlockAndPublish()` are gone.
- `ament_target_dependencies` is deprecated or removed. Use
  `target_link_libraries(... pkg::pkg ${msg_pkg_TARGETS})`, `ament_export_targets(...
  HAS_LIBRARY_TARGET)` and `ament_export_dependencies`.
- `generate_parameter_library` is the norm for controller params. Its generated header is installed
  under `include/<pkg>/`, and the params interface target must be in the same export set.
- ros2_controllers (Lyrical): `JointGroup{Position,Velocity,Effort}Controller` are deprecated in
  favour of `forward_command_controller` with `interface_name`. The JTC `constraints.goal_time`
  default changed to 10 s. `configure_controller` accepts only unconfigured controllers.
- Testing: load hardware through `hardware_interface::ResourceManager(urdf, clock_if, logger_if,
  activate_all, rate)` with `read()`/`write()` cycles. Test controllers directly via
  `init(params)`, `configure()`, `assign_interfaces(...)` and `get_node()->activate()`, using
  `CommandInterface`/`StateInterface` built from `InterfaceDescription`.

### ROS 2 core skills (node-creation, lifecycle, messaging, service-action, launch-config, testing)

- No skill pins a distro. State Lyrical and remove distro-specific advice that no longer holds.
- ament_python: current setuptools ignores `tests_require`, so colcon falls back to unittest and runs
  0 tests. Use `extras_require={'test': ['pytest']}` plus `<test_depend>python3-pytest</test_depend>`.
  No ROS skill currently explains ament_python `setup.py`/`setup.cfg`/resource-marker packaging.
- C++ packages: export a library with `ament_export_targets` so other packages can
  `find_package` and link `pkg::pkg`, and register components with
  `rclcpp_components_register_node`.
- Action servers in rclpy need a `ReentrantCallbackGroup` (or a separate group) plus
  `MultiThreadedExecutor`, or cancel and feedback starve while `execute` runs.
- Tests synchronise on futures and executors (`spin_until_future_complete`, `spin_all`), never
  `sleep`. Use `launch_testing` with `ReadyToTest` for end-to-end tests.

### Language skills

- `python-patterns` / `python-testing` still show `typing.List/Dict/Optional`. Prefer builtin
  generics, `X | None` and PEP 695 syntax where Python ≥ 3.12. Make sure `mypy --strict`-clean
  examples, frozen dataclasses, `StrEnum` and exception chaining (`raise ... from`) are covered.
  The sleep usages in examples should not become test-synchronisation advice.
- `cpp-coding-standards` / `cpp-testing`: modern locking (`std::scoped_lock`), condition-variable
  predicates, drain-on-shutdown worker patterns, `std::span` APIs, `[[nodiscard]]`, warnings with
  `-Wconversion`, ThreadSanitizer, and how to run clang-tidy when the default GCC install lacks
  libstdc++ headers (`--gcc-install-dir`).
- `rust-patterns` / `rust-testing` are new seeds. Strengthen them where the runs show gaps (typed
  errors, clippy pedantic, panic-safe worker pools, CLI integration tests).

## Reference

ECC (`github.com/ysyecust/everything-claude-code`) is the format reference for language skills:
"When to Use / When NOT to Use", DO / DON'T lists, short runnable examples, and a review checklist.
