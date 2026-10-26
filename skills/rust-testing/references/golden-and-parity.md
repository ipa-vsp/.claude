# Golden Files and Parity Oracles

## Where things live (Arche)

| Item | Path |
|---|---|
| Input robots (URDF/SRDF from C++ tests) | `arche/docs/migration/fixtures/robots/`, provenance in `fixtures/manifest.json` |
| Golden outputs (to be created by the C++ dump harness) | `arche/docs/migration/fixtures/golden/<area>/<case>.json` |
| Loader | `arche_testkit::robot_fixture(name)`, `robot_fixture_names()` |

The golden directory does not exist yet. It is created together with the
approved test-only C++ dump harness (STATUS.md §6 item 4). Do not create
golden files by hand or from the Rust implementation.

## Golden file format

One JSON document per case, with provenance first:

```json
{
  "schema": "arche.golden.v1",
  "provenance": {
    "generator": "arche_kinematics_pinocchio/test/dump_golden.cpp",
    "commit": "e0d0e86c936b431c69345617669ae9697c4b537a",
    "platform": "Ubuntu 26.04, ROS 2 Lyrical, GCC 15.2.0, Pinocchio 4.1.0",
    "command": "colcon test --packages-select arche_kinematics_pinocchio --ctest-args -R dump",
    "date": "2026-11-02"
  },
  "input": {
    "robot": "robots/arche_kinematics_pinocchio__test_fk__two_link.urdf",
    "robot_sha256": "<from manifest.json>",
    "base_type": "fixed",
    "q": [0.3, -0.7]
  },
  "units": { "translation": "m", "rotation": "quaternion xyzw", "q": "rad" },
  "tolerance": { "translation_m": 1e-9, "rotation_rad": 1e-9 },
  "output": {
    "frame": "tool0",
    "translation": [0.0, 0.0, 0.0],
    "rotation_xyzw": [0.0, 0.0, 0.0, 1.0]
  }
}
```

(Values above are placeholders showing the shape, not real data.)

Rules:
- `tolerance` is stored *with* the golden and comes from the C++ test.
  The Rust test reads it rather than hard-coding a looser one.
- `robot_sha256` must match `manifest.json`; the loader should check it,
  so a silently edited fixture fails loudly.
- Floats are written with full round-trip precision (`%.17g` in C++,
  default `{}` Display in Rust).
- Arrays use a stated order (joint order = model order, matrices
  column-major) and the `units` block says which.

## Update protocol

1. A golden changes only when (a) the C++ reference changed on purpose,
   or (b) an ADR accepts a behaviour change.
2. Regenerate with the recorded `command`. Commit the regenerated files
   in their own commit, with the diff summary (which cases moved, by how much).
3. Never regenerate goldens from the Rust implementation. That turns a
   parity test into a snapshot test of itself.

## Statistical oracles (stochastic planners / IK)

The C++ tests use success-rate thresholds (`test_clik` ≥ 95 %,
`test_arm_planning` ≥ 80 %, `test_collision_avoidance` ≥ 70 %). Port them as:

```rust
/// Wilson score interval for k successes out of n (z = 1.96 → 95 %).
fn wilson(k: u32, n: u32, z: f64) -> (f64, f64) {
    let (k, n) = (f64::from(k), f64::from(n));
    let p = k / n;
    let denom = 1.0 + z * z / n;
    let centre = (p + z * z / (2.0 * n)) / denom;
    let half = z * ((p * (1.0 - p) / n) + z * z / (4.0 * n * n)).sqrt() / denom;
    (centre - half, centre + half)
}

#[test]
fn clik_success_rate_matches_cpp_threshold() {
    const N: u32 = 200;
    let mut ok = 0;
    for seed in 0..u64::from(N) {
        if solve_random_reachable_target(seed).is_ok() { ok += 1; }
    }
    let (lo, hi) = wilson(ok, N, 1.96);
    // C++ test_clik threshold: >= 95 % (point estimate).
    assert!(f64::from(ok) / f64::from(N) >= 0.95,
        "success {ok}/{N}, 95% CI [{lo:.3}, {hi:.3}]");
}
```

- Seeds are the loop index: deterministic, reproducible, no flake.
- Also log the CI. If the lower bound is far below the threshold, the
  test passes by luck of the seed set. Increase N, or raise it in review.
- When comparing Rust against C++ (not against a fixed threshold), run both
  on the **same seed list and targets** and compare success counts with a
  two-proportion test or overlapping CIs. Report both rates.

## Parity test naming and documentation

```rust
/// Parity: <C++ package>/test/<file>.cpp `<TestSuite.TestName>`
/// Oracle: analytic | golden | stat  — tolerance: <value + unit>
/// Changes vs C++: none | ADR NNNN
#[test]
fn <area>_<case>_matches_cpp() { ... }
```

`STATUS.md` evidence for a step lists these test names and the command that
ran them.
