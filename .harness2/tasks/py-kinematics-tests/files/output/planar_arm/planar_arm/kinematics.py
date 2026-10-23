"""Kinematics of a planar 2-link arm (angles in radians, lengths in metres)."""

from __future__ import annotations

import math


class UnreachableError(ValueError):
    """The target lies outside the arm's workspace."""


def forward(q1: float, q2: float, l1: float, l2: float) -> tuple[float, float]:
    """End-effector position for joint angles q1, q2."""
    if l1 <= 0 or l2 <= 0:
        raise ValueError("link lengths must be positive")
    x = l1 * math.cos(q1) + l2 * math.cos(q1 + q2)
    y = l1 * math.sin(q1) + l2 * math.sin(q1 + q2)
    return x, y


def inverse(
    x: float, y: float, l1: float, l2: float, elbow_up: bool = True
) -> tuple[float, float]:
    """Joint angles that reach (x, y). Raises UnreachableError outside the annulus."""
    if l1 <= 0 or l2 <= 0:
        raise ValueError("link lengths must be positive")
    r2 = x * x + y * y
    r = math.sqrt(r2)
    if r > l1 + l2 or r < abs(l1 - l2):
        raise UnreachableError(f"target ({x}, {y}) at distance {r:.4f} is unreachable")
    c2 = (r2 - l1 * l1 - l2 * l2) / (2 * l1 * l2)
    c2 = max(-1.0, min(1.0, c2))
    s2 = math.sqrt(1.0 - c2 * c2)
    if elbow_up:
        s2 = -s2
    q2 = math.atan2(s2, c2)
    q1 = math.atan2(y, x) - math.atan2(l2 * s2, l1 + l2 * c2)
    return q1, q2


def jacobian(q1: float, q2: float, l1: float, l2: float) -> tuple[tuple[float, float], ...]:
    """2x2 Jacobian d(x, y)/d(q1, q2)."""
    s1, c1 = math.sin(q1), math.cos(q1)
    s12, c12 = math.sin(q1 + q2), math.cos(q1 + q2)
    return (
        (-l1 * s1 - l2 * s12, -l2 * s12),
        (l1 * c1 + l2 * c12, l2 * c12),
    )


def is_singular(q2: float, tol: float = 1e-9) -> bool:
    """True when the arm is fully stretched or folded (det J == 0)."""
    return abs(math.sin(q2)) < tol
