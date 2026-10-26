---
name: rust-testing
description: Testing numerical and robotics Rust code — float tolerances, SE(3)/quaternion/Lie-group comparisons, finite-difference Jacobian checks, property tests, seeded randomness, golden files and C++ parity tests, statistical oracles for stochastic solvers. Use when writing or fixing Rust tests, porting C++ gtests to Rust, choosing tolerances, adding fixtures, or diagnosing flaky numeric tests; also the general cargo test workflow — unit/integration/doc layout, error-contract and CLI tests, mockall mocks, concurrency tests without sleeps, coverage (cargo llvm-cov).
---

# Numerical and Robotics Testing in Rust

How to write Rust tests that catch real numerical bugs without being
flaky, and how to prove parity with a legacy C++ implementation. In Arche,
shared helpers live in `rust/crates/arche-testkit` (dev-dependency only).

## When to Use

- Writing unit, integration or doc tests for kinematics, geometry,
  collision, planning or trajectory code
- Porting a C++ gtest (`EXPECT_NEAR`, success-rate loops) to Rust
- Choosing or justifying a tolerance
- Adding or regenerating golden fixtures
- Testing stochastic planners/IK (success rates, seeds)
- A numeric test is flaky, platform-dependent or slow

### When NOT to Use

- Timing and solver comparison studies → `robotics-planning-benchmark`
- FFI-specific memory testing (sanitizers) → `rust-ffi`
- Implementing features without test changes → `rust-patterns`
- C++ tests of the legacy packages → `cpp-testing`
- ROS 2 launch/integration tests → `ros2_testing`

## Test Layout

| Kind | Location | Runs in CI | Notes |
|---|---|---|---|
| Unit | `#[cfg(test)] mod tests` beside code | `cargo test` | private access, fast, no I/O except fixtures |
| Integration | `crates/<c>/tests/*.rs` | `cargo test` | public API only |
| Doc | `///` examples | `cargo test --doc` | every main entry point gets one |
| Parity | `crates/<c>/tests/parity_*.rs` | `cargo test` | compares with C++ oracle values/fixtures |
| Property | in unit/integration tests | `cargo test` | fixed case count, seed printed on failure |
| Slow/statistical | `#[ignore = "slow: ..."]` | nightly job `cargo test -- --ignored` | must still be deterministic |

Run everything: `cargo test --workspace --all-targets --locked` and
`cargo test --workspace --doc --locked`.

## Rule 1: Never Compare Floats Exactly

`assert_eq!` on `f64` is wrong except for values that are exact by
construction (copied input, integer-valued constants). The `float_cmp` lint
warns about it.

```rust
use arche_testkit::{Tolerance, assert_all_close, assert_close};

// Port of C++ EXPECT_NEAR(x, 0.5, 1e-9): keep the C++ tolerance.
assert_close(pose.translation[0], 0.5, Tolerance::abs(1e-9));
// Large magnitudes: relative band.
assert_close(mass_matrix_trace, 812.4, Tolerance::rel(1e-10));
assert_all_close(&q_out, &q_expected, Tolerance::abs(1e-12));
```

Choosing the band:
1. **Porting a C++ assertion → use its tolerance.** Loosening it needs a
   comment that names the cause (different algorithm, accumulated
   rounding). Tightening is fine.
2. **Analytic result after k floating-point operations** → about
   `k * f64::EPSILON * scale`. 1e-12 for short chains on O(1) values.
3. **Iterative solvers** → tolerance = solver's own convergence threshold
   × a safety factor (state both).
4. **Finite differences** → about √ε ≈ 1e-8 relative for central differences
   at step h ≈ 1e-6 → use 1e-5…1e-6 absolute on O(1) Jacobians (the C++
   tests use 1e-5).
5. Always state the **unit**: `1e-9` m, `1e-10` rad.

## Rule 2: Compare Geometry in the Right Space

- **Rotations:** never compare quaternion components directly. `q` and
  `-q` are the same rotation. Compare the angle of `R_actual⁻¹ R_expected`,
  or `|dot(q_a, q_b)| ≥ 1 - tol`.
- **Poses:** compare translation (m) and rotation angle (rad) separately,
  with separate tolerances. Do not use one norm over a 4×4 matrix.
- **Angles:** wrap differences to (-π, π] before comparing.
- **Lie groups:** for `integrate`/`difference` round trips, check
  `difference(q, integrate(q, v)) ≈ v` and
  `integrate(q, difference(q, r)) ≈ r` (the C++ `test_lie_group` cases). On
  planar bases, `[cos θ, sin θ]` must stay normalised.
- Code for these comparisons: [references/numerical-oracles.md](references/numerical-oracles.md).

## Rule 3: Derivatives Are Checked by Finite Differences

Every analytic Jacobian gets a central-difference test on several
configurations, including near-singular ones. On Lie groups, perturb with
`integrate(q, h·eᵢ)` (tangent space), not `q + h·eᵢ`. Example in
`references/numerical-oracles.md`.

## Rule 4: Randomness Is Seeded and Reported

- Never `thread_rng()` in tests. Use a seeded RNG
  (`rand_chacha::ChaCha8Rng::seed_from_u64(SEED)`) once the workspace adds
  `rand`. Until then, use fixed configuration lists.
- Put the seed in every assertion message for sampled cases:
  `assert!(ok, "seed {seed}, trial {i}: ...")`.
- Property tests (`proptest`, once approved as a dependency): fixed
  `cases`, `failure_persistence` file committed under `proptest-regressions/`.
  Generate *valid* inputs (unit quaternions, in-limit joints) with
  strategies, not filters, so few cases are rejected.

Good property candidates in robotics:
| Property | Example |
|---|---|
| Inverse | `T · T⁻¹ = I`, `difference(q, q) = 0` |
| Composition | `(A·B)·C = A·(B·C)`; `fk(q)` vs product of joint transforms |
| Invariance | collision result independent of object insertion order |
| Monotonicity | world revision strictly increases per command |
| Round trip | parse → serialise → parse yields equal model |
| Bounds | IK solution within joint limits when `respect_limits` is set |

## Rule 5: Parity With the C++ Reference

Parity tests prove that the Rust port reproduces the legacy behaviour.
Source of truth: `arche/docs/migration/COMPATIBILITY_MATRIX.md` (oracle and
tolerance per component).

| Oracle type | Rust test does |
|---|---|
| `analytic` | Re-implement the C++ gtest's analytic expectation with the same tolerance; name the source test in a doc comment |
| `golden` | Load the recorded C++ output (JSON) and compare with the documented tolerance |
| `stat` | Run N fixed seeds, assert success rate ≥ the C++ threshold, report the Wilson interval |

```rust
/// Parity: arche_kinematics_pinocchio/test/test_fk.cpp `TwoLinkFk`
/// (tolerance 1e-9 m as in the C++ test).
#[test]
fn two_link_fk_matches_cpp() {
    let urdf = arche_testkit::robot_fixture(
        "arche_kinematics_pinocchio__test_fk__two_link.urdf").unwrap();
    // ... build model, evaluate, assert_close(..., Tolerance::abs(1e-9))
}
```

- **Never invent golden values.** Goldens are produced by running the C++
  code (test-only dump harness, STATUS §6 item 4). Each golden file records
  its provenance; see [references/golden-and-parity.md](references/golden-and-parity.md).
- **Never regenerate a golden to make a failing test pass** without
  explaining the diff in the PR.
- If C++ behaviour is intentionally changed (ADR), the parity test asserts
  the *new* behaviour and cites the ADR.

## Rule 6: No Sleeps, No Timing Assertions

- Concurrency tests synchronise with channels/barriers, never with
  `thread::sleep`.
- Do not assert on wall time in unit tests. Performance belongs in
  benchmarks (`robotics-planning-benchmark`).
- Time budgets in planners are tested with an injected clock or a
  zero/near-zero budget that must return `Timeout` promptly.

## Rule 7: Platform Determinism

- Results may differ in the last bits across CPUs/compilers (FMA, libm).
  Golden comparisons always use tolerances, never byte equality, unless the
  value is integral (counts, indices, classifications).
- Discrete outcomes (in collision or not, solution found or not) must
  match exactly on the fixture cases. Pick fixtures away from decision
  boundaries, or document the boundary cases.

## Flaky Test Triage

1. Re-run with the printed seed: does it reproduce deterministically?
2. If only some seeds fail → genuine robustness bug or a too-tight
   statistical threshold. Compute the Wilson interval before changing anything.
3. If it differs across machines → floating-point sensitivity. Look for
   exact comparisons, unsorted `HashMap` iteration, or decision-boundary
   fixtures.
4. Never "fix" a flake with retries or by widening a tolerance without
   a recorded reason.

## General Cargo Test Workflow

TDD loop: red → green → refactor. Determinism everywhere: no sleeps, no
wall-clock, no shared global state between tests.

### Error Contracts, CLI Behaviour and Concurrent Progress

- Assert error variants and relevant fields, plus `source()` for wrapped
  errors. Test required trait bounds at compile time when they belong to the
  public contract. Avoid exact OS error wording or incidental debug formatting.
- Run CLI integration tests with the Cargo-built binary
  (`env!("CARGO_BIN_EXE_<binary-name>")`). Use isolated temporary directories
  and assert exit status, stdout/stderr roles and useful diagnostics.
- Use `recv_timeout`, condition predicates or completion signals for bounded
  waits. To verify parallelism, have jobs announce readiness and wait on a
  releasable gate; require all readiness signals before release. A bare
  barrier can deadlock the suite when the implementation accidentally
  serialises jobs.
- Ensure failure paths release gates and join threads. Use an outer process
  timeout for deadlock-prone tests; timing out an assertion does not
  interrupt a blocked destructor or join.
- When panic resilience is promised, queue a panicking job followed by a
  normal job in a single-worker pool and verify bounded completion. Check
  drain/cancel behaviour on explicit shutdown and `Drop` according to the
  documented contract.
- Run unit, integration and doc tests under the project's feature matrix;
  keep build artefacts out of committed fixtures without deleting user data.

### Testing errors (match the variant, not the message)

```rust
#[test]
fn missing_field_is_reported_with_line() {
    let err = parse("name=\n").unwrap_err();
    assert!(matches!(err, ParseError::MissingField { line: 1, .. }), "got {err:?}");
}
```

### Tests returning `Result`, table-driven tests

```rust
#[test]
fn parses_valid_input() -> Result<(), Box<dyn std::error::Error>> {
    let cfg = parse("rate=10\n")?;
    assert_close(cfg.rate, 10.0, Tolerance::abs(1e-12));
    Ok(())
}

#[test]
fn normalizes_names() {
    let cases = [("  Foo ", "foo"), ("BAR", "bar"), ("", "")];
    for (input, expected) in cases {
        assert_eq!(normalize(input), expected, "input: {input:?}");
    }
}
```

### Mock a trait (mockall)

```rust
#[cfg_attr(test, mockall::automock)]
pub trait Clock { fn now_ms(&self) -> u64; }

#[test]
fn times_out_after_deadline() {
    let mut clock = MockClock::new();
    clock.expect_now_ms().return_const(5_000u64);
    assert!(is_expired(&clock, 1_000));
}
```

Prefer hand-written fakes for stateful collaborators; inject time and I/O
through traits.

### Concurrency tests without sleeps

```rust
use std::sync::mpsc;
use std::time::Duration;

#[test]
fn worker_processes_job() {
    let (done_tx, done_rx) = mpsc::channel();
    let pool = Pool::new(2);
    pool.execute(move || done_tx.send(42).unwrap());
    // bounded wait on a signal, not a fixed sleep
    assert_eq!(done_rx.recv_timeout(Duration::from_secs(5)).unwrap(), 42);
}
```

### Running tests and coverage

```bash
cargo test parser::                 # filter by path
cargo test -- --nocapture           # show println!
cargo test -- --test-threads=1      # diagnose shared-state flakiness
cargo nextest run                   # per-test processes (if installed)
cargo llvm-cov --all-targets --fail-under-lines 80
cargo llvm-cov --html               # target/llvm-cov/html
```

### DO / DON'T

- DO name tests after behaviour (`rejects_negative_rate`), one behaviour per test
- DO use `tempfile::tempdir()` for filesystem tests; never fixed paths
- DO run `cargo clippy --all-targets` so test code is linted too
- DON'T `#[ignore]` a flaky test without an issue reference
- DON'T `unwrap()` in helpers without context — use `expect("why")`
- DON'T test private implementation details from integration tests

## References

- [references/numerical-oracles.md](references/numerical-oracles.md) —
  rotation/pose comparison, angle wrapping, finite-difference Jacobian
  check, Lie-group round trips (code)
- [references/golden-and-parity.md](references/golden-and-parity.md) —
  golden file format and provenance, update protocol, statistical oracle
  with Wilson interval (code)
