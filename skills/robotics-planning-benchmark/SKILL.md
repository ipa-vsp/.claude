---
name: robotics-planning-benchmark
description: Reproducible benchmarking of motion planners, IK solvers and collision checkers — fixed scenarios and seeds, fair time budgets, independent result validation, metric definitions with units, repeated trials with confidence intervals, environment metadata and raw-data export. Use when measuring or comparing planning/IK/collision performance, writing criterion micro-benchmarks, designing a benchmark suite or reporting numbers in docs, PRs or papers.
---

# Reproducible Robotics Planning Benchmarks

How to produce planner, IK and collision numbers that someone else can
rerun and get the same conclusions. Applies to quick PR measurements
(cold/warm collision calls, Step 07), backend comparisons (Step 08), the
benchmark suite (Step 14) and research evaluations (Steps 18–21).

## When to Use

- "Is the Rust port slower/faster than C++?"
- Comparing planners, IK solvers or collision backends on the same problems
- Adding `criterion` micro-benchmarks
- Designing scenario files, metrics or report formats for `arche-benchmark`
- Writing performance claims in docs, PR descriptions or papers

### When NOT to Use

- Correctness and parity tests → `rust-testing` (benchmarks never replace
  tests; a benchmark run assumes the tests pass)
- Profiling a single hot loop to optimise it → use a profiler
  (`perf`, `cargo flamegraph`). Benchmark before and after only to confirm.

## Two Kinds of Benchmark

| | Micro-benchmark | Scenario benchmark |
|---|---|---|
| Question | how fast is one call (FK, distance query)? | how well does solver X solve problem set P? |
| Tool | `criterion` in `crates/<c>/benches/` | `arche-benchmark` runner (Step 14) |
| Output | time distribution per call | per-trial records → aggregated report |
| Inputs | fixed fixture robot + fixed configurations | scenario files (robot, scene, queries, constraints, budgets, seeds) |
| Runs in CI | compile only (`cargo bench --no-run`); measured on demand | small smoke subset; full runs on a pinned machine |

## Non-Negotiables

1. **Identical inputs.** Every solver in a comparison gets the same robot
   model (hash), scene (hash), start/goal pairs, constraints, time budget and
   seed list. Record all of them in the output.
2. **Independent validation.** A trial is a success only if the
   *benchmark harness* verifies the result with a common validator
   (collision at a stated resolution, joint limits, goal tolerance, timing
   constraints). The planner's own "success" flag is recorded but never
   trusted alone.
3. **Failures count.** Timeouts, crashes, exceptions and invalid results
   are recorded as failures with a reason. Never drop them from the
   denominator. Time statistics are reported over successes *and* say so.
4. **Repetitions and uncertainty.** At least 30 trials per (solver, query)
   for stochastic solvers, with distinct recorded seeds. Report success rate
   with a Wilson 95 % CI, and times as median + IQR (plus p95). Do not
   report mean ± std for skewed planning times.
5. **Cold vs warm separated.** Model loading, scene construction, first
   call (allocation, caches) and steady-state calls are measured separately
   and labelled.
6. **Environment recorded.** Commit, dirty flag, toolchain, compiler flags,
   features, solver versions, CPU model, cores used, governor/turbo, OS,
   kernel, ROS distro, date. A number without this metadata is anecdotal.
7. **Raw data published.** Every aggregate table can be regenerated from
   the committed or archived raw per-trial records (JSON Lines / CSV).

## Fairness Rules

- **Same time budget** and the same meaning of it (wall clock, including
  setup or not, stated once for all solvers).
- **Default vs tuned:** report defaults; if a solver is tuned, tune all
  solvers with the same effort and publish the parameters.
- **Same collision checker** for validation across planners, even when
  planners use different checkers internally.
- **Same threads:** single-threaded unless the comparison is explicitly
  about parallelism. Record thread counts.
- **No test-set tuning:** parameters tuned on scenario set A are evaluated
  on set B.
- When comparing Rust port vs C++ reference, run both on the same machine
  in the same session, interleaved (ABAB…), to cancel thermal and
  frequency drift.

## Metrics (summary)

Full definitions, formulas and units: [references/metrics.md](references/metrics.md).

| Metric | Unit | Notes |
|---|---|---|
| success rate | — | validated by harness, Wilson CI |
| time to solution | s (wall, monotonic clock) | median/IQR/p95 over successes; plus time-to-failure |
| path length (joint space) | rad (weighted) | state the weights; base DoFs in m vs rad handled explicitly |
| TCP path length | m | Cartesian, from FK at a stated resolution |
| min clearance | m | signed distance along the densified path |
| joint-limit margin | rad | min over path and joints of distance to limit |
| smoothness | rad/s³ (jerk) | after time parameterisation with stated limits |
| velocity/acceleration/jerk violations | count, max excess | against the robot's limits |
| manipulability / σ_min(J) | — | singularity indicator along path |
| IK: success, residual, iterations, distinct solutions | m/rad, count | residual in position and orientation separately |
| collision: queries/s, cold vs warm latency | s | per geometry type and scene size |

## Micro-Benchmark Pattern (criterion)

```rust
// crates/arche-model/benches/fk.rs  (illustrative)
use criterion::{Criterion, black_box, criterion_group, criterion_main};

fn fk_two_link(c: &mut Criterion) {
    let model = load_fixture_model("arche_kinematics_pinocchio__test_fk__two_link.urdf");
    let q = [0.3, -0.7];                       // fixed input, no RNG in the loop
    c.bench_function("fk/two_link/warm", |b| {
        b.iter(|| model.frame_pose(black_box(&q), "tool0"))
    });
}

criterion_group!(benches, fk_two_link);
criterion_main!(benches);
```

- Build inputs outside `b.iter`; use `black_box` on inputs and outputs.
- Use `iter_batched` when each iteration needs fresh state (cold calls).
- Run with `cargo bench -p <crate> -- --save-baseline <name>`; compare
  with `--baseline`. Commit nothing from `target/criterion`; summarise in
  the PR with the machine metadata.
- `criterion` is not a workspace dependency yet. Adding it goes through
  `cargo deny check`, as a `[dev-dependencies]` entry only.

## Scenario Benchmark Workflow

1. **Define scenarios** (versioned files): robot + hash, scene + hash, query
   list (start, goal, constraints), time budget, seed list, validator settings.
2. **Run**: harness loops solver × query × seed. Each trial gets a fresh solver
   (or an explicitly warm one), a monotonic timer around `plan()` only, and
   writes one JSON line immediately (crash-safe).
3. **Validate**: re-check every returned path with the common validator.
4. **Aggregate** in a separate step from raw records (no aggregation inside
   the runner).
5. **Report**: methodology section first, then tables, then plots. See
   [references/report-template.md](references/report-template.md).

## Machine Hygiene (Linux)

- Performance governor or fixed frequency; disable turbo for A/B
  comparisons, or report that it was on.
- Idle machine; no builds running; pin to cores (`taskset`) for
  single-threaded runs; note SMT.
- Release profile (`--profile bench` in Arche: release + debug info), never debug builds.
- Warm-up runs discarded and counted in metadata.

## DO / DON'T

**DO**
- Publish seeds, scenarios, raw data and the exact command line
- Report failures and their reasons as prominently as speed
- Show distributions (box/violin or ECDF of time-to-solution), not only medians
- State the hypothesis before running a research comparison

**DON'T**
- Compare numbers from different machines or sessions in one table
- Exclude "outlier" trials without a recorded rule applied to all solvers
- Report the best of N runs
- Time logging, serialization or visualisation together with planning
- Claim significance from overlapping CIs or from a single seed set

## References

- [references/metrics.md](references/metrics.md) — exact metric
  definitions, formulas, units, edge cases
- [references/report-template.md](references/report-template.md) —
  environment metadata schema, per-trial record schema, report outline
