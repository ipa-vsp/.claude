import dataclasses
from pathlib import Path

import pytest

import robot_config
from robot_config import ConfigError, ControllerType, RobotConfig, load_config

VALID = """
name = "arm"
update_rate_hz = 250
[[joints]]
name = "j1"
min_position = -1.0
max_position = 1.0
max_velocity = 2.0
[[joints]]
name = "j2"
min_position = -2.0
max_position = 2.0
max_velocity = 1.5
[controller]
type = "velocity"
gains = { p = 10.0, i = 0.5 }
"""


def write(tmp_path: Path, text: str) -> Path:
    p = tmp_path / "cfg.toml"
    p.write_text(text)
    return p


def test_valid_types(tmp_path):
    cfg = load_config(write(tmp_path, VALID))
    assert isinstance(cfg, RobotConfig)
    assert cfg.name == "arm"
    assert cfg.update_rate_hz == 250
    assert isinstance(cfg.joints, tuple) and len(cfg.joints) == 2
    assert cfg.joints[1].name == "j2" and cfg.joints[1].max_velocity == 1.5
    assert cfg.controller.type is ControllerType.VELOCITY
    assert cfg.controller.type == "velocity"
    assert cfg.controller.gains == {"p": 10.0, "i": 0.5}
    assert list(robot_config.joint_names(cfg)) == ["j1", "j2"]


def test_accepts_str_path(tmp_path):
    assert load_config(str(write(tmp_path, VALID))).name == "arm"


def test_default_rate(tmp_path):
    cfg = load_config(write(tmp_path, VALID.replace("update_rate_hz = 250\n", "")))
    assert cfg.update_rate_hz == 100


def test_frozen(tmp_path):
    cfg = load_config(write(tmp_path, VALID))
    with pytest.raises(dataclasses.FrozenInstanceError):
        cfg.name = "x"  # type: ignore[misc]
    with pytest.raises(dataclasses.FrozenInstanceError):
        cfg.joints[0].max_velocity = 9.0  # type: ignore[misc]


def test_config_error_is_value_error():
    assert issubclass(ConfigError, ValueError)


@pytest.mark.parametrize(
    "mutate, needle",
    [
        (lambda t: t.replace('name = "arm"\n', ""), "name"),
        (lambda t: t.replace('type = "velocity"', 'type = "torque"'), "type"),
        (lambda t: t.replace("update_rate_hz = 250", "update_rate_hz = 0"), "update_rate_hz"),
        (lambda t: t.replace("max_position = 1.0", "max_position = -1.0"), "j1"),
        (lambda t: t.replace("max_velocity = 1.5", "max_velocity = -1.5"), "j2"),
        (lambda t: t.replace('name = "j2"', 'name = "j1"'), "j1"),
        (lambda t: t.replace("max_velocity = 2.0\n", ""), "max_velocity"),
        (lambda t: t.replace("p = 10.0", 'p = "high"'), "p"),
        (lambda t: t.split("[controller]")[0], "controller"),
        (lambda t: t + "\nthis is = = not toml\n", ""),
    ],
    ids=["missing-name", "bad-type", "zero-rate", "inverted-limits", "neg-velocity",
         "duplicate-joint", "missing-joint-field", "non-numeric-gain", "missing-controller",
         "bad-toml"],
)
def test_rejections(tmp_path, mutate, needle):
    with pytest.raises(ConfigError) as exc:
        load_config(write(tmp_path, mutate(VALID)))
    assert needle in str(exc.value)


def test_empty_joints(tmp_path):
    text = VALID.split("[[joints]]")[0] + "joints = []\n[controller]\ntype = \"position\"\n"
    with pytest.raises(ConfigError):
        load_config(write(tmp_path, text))


def test_missing_file(tmp_path):
    with pytest.raises(ConfigError):
        load_config(tmp_path / "nope.toml")
