import dataclasses

import pytest

from gripper_action.domain import GripperState, SimulatedGripper


def test_starts_open_and_validates():
    g = SimulatedGripper(max_opening=0.08, speed=0.05)
    assert g.position == pytest.approx(0.08)
    with pytest.raises(ValueError):
        SimulatedGripper(max_opening=0.0, speed=0.05)
    with pytest.raises(ValueError):
        SimulatedGripper(max_opening=0.08, speed=-1.0)


def test_rate_limited_motion_and_reach():
    g = SimulatedGripper(max_opening=0.08, speed=0.05)
    s = g.step(0.0, 0.1)
    assert isinstance(s, GripperState)
    assert s.position == pytest.approx(0.075)
    assert not s.reached and not s.stalled
    for _ in range(100):
        s = g.step(0.06, 0.1)
    assert s.position == pytest.approx(0.06) and s.reached and not s.stalled


def test_stalls_on_object():
    g = SimulatedGripper(max_opening=0.08, speed=0.05, object_width=0.03)
    s = g.step(0.0, 0.1)
    for _ in range(100):
        s = g.step(0.0, 0.1)
    assert s.position == pytest.approx(0.03)
    assert s.stalled and not s.reached


def test_state_frozen():
    s = SimulatedGripper(0.08, 0.05).step(0.08, 0.1)
    with pytest.raises(dataclasses.FrozenInstanceError):
        s.position = 1.0  # type: ignore[misc]
