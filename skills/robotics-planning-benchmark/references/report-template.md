# Benchmark Records and Report Template

## 1. Environment metadata (one per run, `run.json`)

```json
{
  "schema": "arche.bench.run.v1",
  "run_id": "2026-11-20T10-31-02Z-ab12cd",
  "command": "arche-benchmark run scenarios/arm7_shelf.toml --solvers trajopt,ompl.rrtconnect",
  "code": { "commit": "<sha>", "dirty": false, "rust_toolchain": "1.99.1",
            "profile": "bench", "features": ["ompl"], "rustflags": "" },
  "solvers": [
    { "id": "arche_planner_ompl/OmplPlanner", "algorithm": "RRTConnect",
      "backend_versions": { "ompl": "2.0.2" }, "params": { "range": 0.0 } }
  ],
  "machine": { "cpu": "AMD Ryzen 9 7950X", "cores_used": 1, "smt": true,
               "governor": "performance", "turbo": false, "ram_gb": 64,
               "os": "Ubuntu 26.04.1", "kernel": "7.0.0-38", "ros_distro": "lyrical" },
  "scenario_set": { "file": "scenarios/arm7_shelf.toml", "sha256": "<hash>" },
  "validator": { "collision_backend": "coal", "resolution_rad": 0.01,
                 "goal_tol_m": 0.001, "goal_tol_rad": 0.01 },
  "timing": { "clock": "monotonic", "budget_s": 5.0, "budget_includes_setup": false,
              "warmup_trials": 3 }
}
```

## 2. Per-trial record (JSON Lines, `trials.jsonl`, one line per trial)

```json
{"run_id":"…","solver":"arche_planner_ompl/OmplPlanner","algorithm":"RRTConnect",
 "query":"shelf_pick_03","seed":17,"trial":17,"status":"success","failure_reason":null,
 "solver_reported_success":true,"t_setup_s":0.41,"t_solve_s":0.083,
 "joint_path_len":3.92,"tcp_path_len_m":1.27,"min_clearance_m":0.021,
 "joint_limit_margin":0.14,"min_manipulability":0.012,"duration_s":2.8,
 "vel_violation_max":0.0,"acc_violation_max":0.0,"jerk_integral":41.3,
 "path_points":58,"densify_resolution_rad":0.01}
```

Rules: one line written per trial immediately after it ends; `null` for
metrics not applicable (failures); never overwrite a trials file, append
with a new `run_id`.

## 3. Report outline (`report.md`)

```markdown
# <Title> — <date>

## Question
One sentence hypothesis, for example "Does the native TrajOpt port solve the
arm7 shelf set at least as often as the C++ TrajOpt, within 5 s?"

## Method
- Scenarios: <set, number of queries, link to file + hash>
- Solvers and parameters: <table; defaults vs tuned>
- Seeds: <list or rule, for example 0..29>; trials per (solver, query): <n>
- Budget: <s, what it includes>
- Validator: <backend, resolution, tolerances>
- Time parameterisation: <method, limits>
- Machine and software: <summary; full run.json linked>

## Results
| Solver | Success (95 % CI) | t_solve median [IQR] s | p95 s | TCP length median m | min clearance median m |
|---|---|---|---|---|---|

- Failure breakdown per solver (timeout / no_solution / invalid / error)
- Plots: ECDF of t_solve (log x), success vs budget curve, per-query heatmap

## Discussion
What the data supports, what it does not, threats to validity
(scenario bias, tuning effort, hardware, budget choice).

## Reproduce
Exact commands, commit, and where raw data is archived.
```

## 4. Statistics helpers

- Success rate CI: Wilson score (see `rust-testing/references/golden-and-parity.md`).
- Median CI: bootstrap (≥ 10 000 resamples, fixed RNG seed recorded) or
  the order-statistic interval.
- Paired comparisons (same query + seed for two solvers): report the
  per-query difference distribution. Use a sign test or Wilcoxon signed-rank
  for times, McNemar for success/failure pairs.
- Many solver pairs → correct for multiple comparisons (Holm), or present
  the results as descriptive only.
