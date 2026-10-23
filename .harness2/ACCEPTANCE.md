# Acceptance criteria: harness2 skills-lab run

## Run-level

| ID | Criterion | How it is checked |
|----|-----------|-------------------|
| AC1 | Setup is sound: `harness2 doctor --json` is all ok, the dry-run is ≤ 90 model calls, and every task's check fails on its seed and passes on a reference solution | `harness2 doctor --json`, `harness2 run --split train --dry-run`, scratch verifier (done before commit) |
| AC2 | No regression: the final harness's mean check score ≥ the baseline on the train split, and **≥ the baseline on every held-out test task** | `harness2 eval <run> --json` |
| AC3 | Improvement: the final harness's mean check score is strictly higher than the baseline on at least one domain (cpp, python, rust, ros2, ros2_control) | `harness2 eval <run> --json` |
| AC4 | Scope: `harness2 diff` touches only `.agents/skills/**`, plus at most skill-index rows in `AGENTS.md`, and never `rea-wiki-vault` / `harness2-setup` | `harness2 diff <run>`, `scripts/h2_lab_sync.sh check` after apply |
| AC5 | Skill hygiene: every changed `SKILL.md` keeps valid frontmatter (`name` unchanged, `description` present), and the outdated Lyrical APIs are gone from `ros2-control` | `.harness2/lib/ac5.sh` |
| AC6 | Rust coverage: `rust-patterns` and `rust-testing` exist and are indexed in `CLAUDE.md` / `AGENTS.md` | `.harness2/lib/ac5.sh` |

## Per-task (graded by hidden `check/run.sh`, partial credit = criteria met / total)

Every task's check prints `{"n_passed", "n_criteria", "notes"}`, so harness2 scores partial
progress. Each criterion is a single line in the task's `check/run.sh`.

| Task | Split | Domain | Criteria (summary) |
|------|-------|--------|--------------------|
| cpp-ringbuffer | train | cpp | -Werror build, own ctest, ≥5 tests, hidden API tests, TSan, clang-tidy clean, no raw new/delete |
| cpp-flaky-test | train | cpp | -Werror build, ctest ×50, ≥4 tests, no sleeps, hidden contract (drain on destroy, ordering, concurrent subscribe), TSan |
| py-typed-config | train | python | flake8, mypy --strict, own tests, ≥8 tests, hidden API/validation tests, example loads |
| py-kinematics-tests | train | python | suite passes, branch cov ≥90 %, parametrize + fixtures, kills 6 mutants |
| rust-parser-errors | train | rust | build, clippy, clippy pedantic, own tests, ≥7 tests, hidden variant tests, no unwrap/expect/panic |
| rust-worker-pool | train | rust | build, clippy, own tests, ≥4 tests, hidden behaviour ×5, forbid(unsafe_code), no sleeps |
| ros2-lifecycle-cpp | train | ros2 | colcon build (-Werror=deprecated), own tests, gtests, exported target links, hidden lifecycle/publish test, pure domain, no ament_target_dependencies, launch file, component |
| ros2-py-action | train | ros2 | build, own colcon tests run, launch_testing present, hidden domain + action (goal/reject/cancel) tests, pure domain, flake8, no sleeps |
| r2c-mock-hardware | train | ros2_control | build (-Werror=deprecated), own tests, uses ResourceManager, hidden RM tests, pluginlib export, no deprecated API, xacro, controllers.yaml |
| r2c-controller | train | ros2_control | build (-Werror=deprecated), own tests, generate_parameter_library, exported target, hidden behaviour (clamp, NaN, size, no stale replay), no RealtimeBuffer |
| cpp-span-refactor | test | cpp | -Wconversion -Werror build, own ctest, ≥6 tests, hidden span API, no ptr+len, [[nodiscard]] |
| py-async-bridge | test | python | flake8, mypy --strict, own tests, ≥5 tests, hidden behaviour ×3, no time.sleep |
| rust-cli-config | test | rust | build, clippy, own tests, 6 CLI behaviour checks, no unwrap/expect/panic |
| r2c-broadcaster | test | ros2_control | build (-Werror=deprecated), own tests, exported target, hidden diagnostics test, no deprecated realtime API |

Reference solutions used to validate the checks are kept outside the repo, so they never leak into
the agent's harness.
