from pathlib import Path

from robot_config import load_config

EXAMPLE = Path(__file__).parent.parent / "examples" / "fr3.toml"


def test_loads_example():
    cfg = load_config(EXAMPLE)
    assert cfg["name"] == "fr3"
    assert len(cfg["joints"]) == 2
