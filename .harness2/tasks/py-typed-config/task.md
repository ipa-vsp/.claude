Our robot config loader in `output/robot_config/` hands back raw nested dicts. Any typo in a TOML
file only blows up later as a `KeyError` somewhere deep in the control code. Please refactor it into a
typed, validated API. Keep the package where it is and edit it in place.

What I want:

- `load_config(path: str | os.PathLike[str]) -> RobotConfig`, still exported from `robot_config`.
- Frozen dataclasses, also exported from `robot_config`:
  - `RobotConfig(name: str, update_rate_hz: float, joints: tuple[JointConfig, ...], controller: ControllerConfig)`
  - `JointConfig(name: str, min_position: float, max_position: float, max_velocity: float)`
  - `ControllerConfig(type: ControllerType, gains: dict[str, float])`
  - `ControllerType` is a `StrEnum` with `POSITION = "position"`, `VELOCITY = "velocity"`, `EFFORT = "effort"`.
- Validation errors raise `ConfigError` (exported, a subclass of `ValueError`). The message must name the
  offending key or joint. Reject these:
  - a missing required key: `name`, `joints`, `controller`, `controller.type`, or any joint field
  - `update_rate_hz <= 0`, which still defaults to 100 when absent
  - `min_position >= max_position`, or `max_velocity <= 0`
  - duplicate joint names, or an empty `joints` list
  - an unknown controller type, or a non-numeric gain
  - a file that is missing or not valid TOML
- `joint_names(cfg)` keeps working, but on `RobotConfig`.
- Full type hints. The package must pass `mypy --strict` and flake8 (pycodestyle + pyflakes rules, max line length 100).
- pytest tests in `tests/` that cover the valid example and every rejection above.

`examples/fr3.toml` is a valid file and must keep loading.
