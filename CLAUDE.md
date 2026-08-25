# ROS 2 Clean Architecture Project — Claude Context

This project is set up with **Claude Skills**, **sub-agents**, and
**rules** to facilitate ROS 2 development following **Clean
Architecture** principles. This file is the persistent orientation
note Claude reads on every session; deep content lives in `skills/`,
`rules/`, `agents/`, and `commands/`.

## Skills

### ROS 2 core

| Skill                  | Description                                | Key Components |
| ---------------------- | ------------------------------------------ | -------------- |
| `ros2_node_creation`   | Clean-arch compliant nodes (Py / C++)      | `BaseNode` template, DI, QoS profiles |
| `ros2_lifecycle`       | Managed (lifecycle) nodes                  | Lifecycle templates, state transitions, clients |
| `ros2_messaging`       | Pub/Sub patterns                           | Domain-driven publishers, thread-safe buffers, synchronization |
| `ros2_service_action`  | Services and Actions                       | Server/Client wrappers, domain use case integration |
| `ros2_launch_config`   | Modular launch files                       | Composition, `IncludeLaunchDescription`, parameters, C++ executables |
| `ros2_transforms`      | TF2 management                             | TF2 wrappers without leaking `geometry_msgs` into domain |
| `ros2_diagnostics`     | Health monitoring                          | `diagnostic_updater` integration, frequency monitoring |
| `ros2_bag`             | Data recording                             | Programmatic rosbag2 record / replay |
| `ros2_testing`         | Testing strategy                           | Unit (domain), integration (node), E2E (launch), GTest/GMock |
| `ros2_control`         | Hardware control framework                 | Hardware interfaces, custom controllers, controller manager, URDF |

### Language / framework

| Skill                  | Description |
| ---------------------- | ----------- |
| `python-patterns`      | Pythonic idioms, PEP 8, type hints, robustness |
| `python-testing`       | pytest, TDD, fixtures, mocking, parametrization, coverage |
| `cpp-coding-standards` | C++ Core Guidelines — modern, safe, idiomatic C++ |
| `cpp-test`             | GoogleTest / CTest authoring, flaky-test diagnosis, coverage / sanitizers |
| `pytorch-patterns`     | Training pipelines, model architectures, data loading |
| `ai-first-engineer`    | Engineering operating model for teams where AI agents produce most code |
| `content-engine`       | Platform-native content systems (non-ROS, general use) |

### Learning (manual-only)

| Skill | Description |
| ----- | ----------- |
| `robotics-mentor` | Socratic tutoring across all of robotics (not workspace-specific): Claude asks, the user derives the answer and writes the code |

**`robotics-mentor` is manual-only — never load it automatically, by topic
match, or because a message sounds like a learning question ("explain…", "help
me understand…", "why does…"). Only a literal `/robotics-mentor` activates it.**
Once activated it stays on for the session until the user says "just tell me" /
"exit mentor". Every other skill in this file auto-matches as usual.

To use a skill, reference its file (e.g.
`.claude/skills/ros2_node_creation/SKILL.md`).

## Sub-agents

All sub-agents run on **Opus**. They group into two opt-in workflows:
**`uab`** (building / reviewing code) and **`uat`** (running &
testing the live system).

### `uab` — build & review agents

| Agent | When to use |
|-------|-------------|
| `clean-arch-architect` | **Before** writing ROS 2 code — node vs use case, topic vs service vs action, compose vs split, where a new port belongs. Returns an architectural recommendation with trade-offs, not code. |
| `ros2-style-reviewer`  | **Before** opening a ROS 2 PR — Clean Architecture, lifecycle, QoS, pluginlib, tests, build manifests. Returns a punch list with `file:line` anchors. |
| `code-reviewer`        | After any code change — general quality, security, maintainability review. MUST be used after edits. |
| `cpp-reviewer`         | After any C++ change — memory safety, modern C++ idioms, concurrency, performance. MUST be used for C++. |
| `python-reviewer`      | After any Python change — PEP 8, Pythonic idioms, type hints, security, performance. MUST be used for Python. |
| `cpp-build-resolver`   | When a C++ / CMake / linker build fails — surgical fixes, minimal changes. |
| `pytorch-build-resolver` | When PyTorch training or inference crashes — tensor shape, device, gradient, DataLoader, AMP issues. |
| `ros2-runtime-diagnoser` | When a runtime failure is reported via a pasted log / stack trace / `~/.ros/log` dump — parses, reproduces, isolates root cause, applies a skill-guided fix. |

### `uat` — run & test agents

A pipeline driven by the **main session**: `uat-runner` →
`uat-injector` → `uat-diagnoser` → `uat-fixer` → (re-run `uat-runner`).

| Agent | When to use |
|-------|-------------|
| `uat-runner`    | Starts the app/command under test (`ros2 launch` / `run`, python / C++ binary, `colcon test`). Asks for the command if none is given. |
| `uat-injector`  | Injects the target/goal(s) (`topic pub`, `service call`, `action send_goal`, param set) — single or multiple. Asks for the goal(s) if none given. |
| `uat-diagnoser` | Monitors & diagnoses the result (read-only); reuses the symptom→cause→skill routing of `ros2-runtime-diagnoser`. Hands off to `uat-fixer`. |
| `uat-fixer`     | Applies the minimal, layer-respecting fix; names a uab agent/skill to escalate to when needed. Main session then re-runs `uat-runner`. |

### Agent delegation policy (opt-in via `uab` / `uat`)

**Default: do NOT spawn sub-agents.** Behave normally and handle tasks
inline.

Two per-message opt-in triggers activate the routing tables below. The
opt-in applies to **that message only** — it does not persist unless a
later message repeats the trigger. A message may contain both.

* **`uab`** — *Use Agents for Building.* Activates the build/review
  routing table.
* **`uat`** — *Use Agents for Testing.* Activates the run/test loop.

When a trigger is present, proactively start the matching sub-agent(s)
for any row the task hits, announcing each spawn in one line first.

#### `uab` routing

| Trigger (what just happened / is about to happen) | Spawn this agent | Timing |
| ------------------------------------------------- | ---------------- | ------ |
| About to write a new node, use case, port, or decide topic vs service vs action / compose vs split | `clean-arch-architect` | **Before** writing code |
| Finished editing any source file | `code-reviewer` | After the edit |
| Finished editing any **C++** file (`.cpp`/`.hpp`/`.cc`/`.h`) | `cpp-reviewer` (in addition to `code-reviewer`) | After the edit |
| Finished editing any **Python** file (`.py`) | `python-reviewer` (in addition to `code-reviewer`) | After the edit |
| About to open a ROS 2 / Nav2 PR (or user asks to prep/open one) | `ros2-style-reviewer` | **Before** the PR |
| A C++ / CMake / linker build fails | `cpp-build-resolver` | On failure |
| PyTorch training or inference crashes | `pytorch-build-resolver` | On failure |
| A runtime failure is reported via a pasted log / stack trace / log dump | `ros2-runtime-diagnoser` | On report |

`uab` guidelines:
* **Batch reviews.** After a related set of edits is complete (not after
  every single `Edit` call), trigger the reviewer(s) once on the whole
  change. Don't re-spawn mid-sequence.
* **Skip when trivial.** Pure docs/comment/whitespace edits, or changes
  the user told you not to review, do not trigger a reviewer.
* **One architect pass per feature** — consult `clean-arch-architect`
  once for the design, not for each file it produces.

#### `uat` routing (main-session-orchestrated loop)

The main session runs the agents in sequence, passing each one's report
to the next, and **re-runs `uat-runner` after `uat-fixer`** to confirm.

| Step | Spawn this agent | What it does |
| ---- | ---------------- | ------------ |
| 1. Bring the system up | `uat-runner` | Runs the command under test. **Asks the user** for the run command if not provided. |
| 2. Drive the behaviour | `uat-injector` | Injects single/multiple goal(s). **Asks the user** for the goal/command if not provided. |
| 3. Observe & diagnose | `uat-diagnoser` | Monitors the result, isolates root cause (read-only), names the fix skill. |
| 4. Fix | `uat-fixer` | Applies the minimal fix. May **name** a uab agent/skill to escalate to (it cannot spawn agents itself). |
| 5. Confirm | `uat-runner` (re-run) | Main session re-runs the loop from step 1/2 to verify the fix. |

`uat` guidelines:
* **Runner and Injector must ask** when the command or goal is missing —
  never guess a package, executable, or payload.
* **Sub-agents don't nest.** `uat-fixer` reports an escalation target
  (e.g. `cpp-build-resolver`, `clean-arch-architect`); the main session
  spawns it, then resumes the loop.
* **Stop on PASS.** If `uat-diagnoser` reports PASS, end the loop — do
  not run the Fixer.

The user can always say "skip the agents" / "no review" to suppress
either workflow for a given task.

## Rules

| Rule file                | What it constrains |
| ------------------------ | ------------------ |
| `ros2_general.md`        | Project-wide ROS 2 conventions (naming, layout, launch, params) |
| `ros2_nodes.md`          | Node design — lifecycle, callback groups, parameters |
| `ros2_communication.md`  | Topic naming, QoS profiles, custom interfaces |
| `testing.md`             | Unit / integration / launch test coverage requirements |
| `robot_specific.md`      | Robot-level overrides — replace per project |
| `colcon_build.md`        | Workspace build standards, execution directory constraints, colcon best practices |

## Conventions worth remembering

* **Domain code does not import `rclpy`, `rclcpp`, or any `*_msgs`
  package.** If it needs ROS, it is not domain.
* **Lifecycle by default** for anything owning a resource (sensor,
  actuator, hardware bridge).
* **`declare_parameter` for every parameter** — silent
  `get_parameter` on undeclared names is a bug.
* **QoS matches semantics** — sensor data = best-effort, commands =
  reliable, latched config = transient-local.
* **Tests run via `colcon test`** — never `sleep(N)` to synchronize;
  use futures, conditions, or `launch_testing.ReadyToTest`.

## Common commands

```bash
# Build the workspace
colcon build --symlink-install
source install/setup.bash

# Test
colcon test --packages-select <pkg>
colcon test-result --all
```

See `.claude/commands/ros2.md` for the full reference card (`colcon`,
`ros2`, `rqt`, etc.).
