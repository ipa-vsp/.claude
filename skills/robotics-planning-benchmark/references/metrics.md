# Metric Definitions

All metrics are computed by the harness from the returned path or trajectory
after validation, never taken from solver-reported values. Units are SI; angles
are in rad.

Notation: path = sequence of configurations `q_0 … q_K`, timed trajectory
`(t_k, q_k, q̇_k, q̈_k)`. Densify paths to the validator resolution `δ`
before computing geometric metrics; record `δ`.

## Outcome

| Field | Definition |
|---|---|
| `status` | `success`, `invalid` (returned but failed validation), `timeout`, `no_solution` (solver reported failure within budget), `error` (exception/crash), `cancelled` |
| `failure_reason` | free text for non-success, for example `collision at k=37 (link4 vs table)` |
| success rate | `#success / #trials`. Wilson 95 % interval. |

## Time

| Metric | Definition |
|---|---|
| `t_solve_s` | monotonic wall time from `plan()` call to return, excluding model/scene loading |
| `t_setup_s` | model + scene construction, reported separately (cold cost) |
| `t_first_s` | first query after setup (includes lazy init), separate from steady-state |
| aggregates | median, IQR, p95 over successes. Also report median time-to-failure for timeouts. |

Use `std::time::Instant` (monotonic). Never use system time.

## Path quality (geometric)

| Metric | Formula | Unit / notes |
|---|---|---|
| joint path length | `Σ_k ‖W (q_{k+1} ⊖ q_k)‖₂` | `⊖` = Lie-group difference (base), `W` = stated diagonal weights; report base and arm parts separately for mobile manipulators |
| TCP path length | `Σ_k ‖p_tcp(q_{k+1}) − p_tcp(q_k)‖₂` on the densified path | m; state the TCP frame |
| min clearance | `min_k sd(q_k)` | m; signed distance (negative = penetration) from the common checker |
| mean clearance | `mean_k sd(q_k)` | m; optional |
| joint-limit margin | `min_{k,j} min(q_kj − lo_j, hi_j − q_kj)` | rad or m; continuous joints excluded |
| min manipulability | `min_k sqrt(det(J Jᵀ))` or `min_k σ_min(J)` | state which. Singularity indicator |
| path segments | `K` | count, before densification |

## Trajectory quality (after time parameterisation)

State the time-parameterisation method and the velocity/acceleration
limits used. Parameterise all planners' paths with the **same** method when
comparing geometric planners.

| Metric | Formula | Unit |
|---|---|---|
| duration | `t_K − t_0` | s |
| velocity violation | `max_{k,j} max(0, |q̇_kj| − v_max_j)` and count of samples > 0 | rad/s |
| acceleration violation | as above with `a_max` | rad/s² |
| jerk (smoothness) | `Σ_k ‖(q̈_{k+1} − q̈_k)/(t_{k+1} − t_k)‖² Δt` | rad²/s⁵ (integrated squared jerk); also max jerk |

## IK

| Metric | Definition |
|---|---|
| success | residual below the stated tolerance **and** within joint limits **and** collision-free if requested |
| position residual | `‖p(q) − p*‖` in m |
| orientation residual | rotation angle of `R(q)ᵀ R*` in rad |
| iterations | solver-reported, if available |
| distinct solutions | count after clustering with stated joint-space radius |
| seed sensitivity | success rate over the seed list for a fixed target |

## Collision

| Metric | Definition |
|---|---|
| query latency | per call, split by query kind (boolean / distance / signed distance), cold vs warm |
| throughput | queries/s on a fixed batch of configurations |
| agreement | classification agreement vs reference backend (count of mismatches) and distance error |
| scene scaling | latency vs number of objects/voxels (log-log plot) |

## Edge cases

- Empty path or single configuration → status `invalid` unless start
  already satisfies the goal (then success with length 0, flagged).
- NaN anywhere → `invalid`, reason `nan`.
- Paths from different planners with different densities are always
  densified to the same `δ` before comparison.
