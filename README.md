# `.claude/` — Skills, Agents & Rules

Claude Code configuration for this ROS 2 / Clean Architecture workspace.

```
.claude/
├── CLAUDE.md        # Auto-loaded orientation note (read every session)
├── README.md        # This file — how to use what's in here
├── rules/           # Auto-loaded constraints (layer rules, conventions)
├── skills/          # On-demand playbooks, invoked by name
├── agents/          # Sub-agents, opt-in via `uab` / `uat`
├── commands/        # Slash commands (reference cards)
└── settings.json    # Permissions, hooks, default mode
```

Four things behave differently, and it's worth keeping them straight:

| Thing | Loaded | You trigger it by |
| ----- | ------ | ----------------- |
| **Rules** | Automatically, every session | Nothing — always in effect |
| **Skills** | On demand | `/skill_name`, or just describing the task |
| **`robotics-mentor`** | Manual only | Typing `/robotics-mentor` — nothing else activates it |
| **Agents** | Never by default | Putting `uab` or `uat` in your message |

---

## Skills

A skill is a playbook Claude reads before doing the work — templates,
patterns, and the project's preferred way to solve one class of problem.
Each lives in `skills/<name>/SKILL.md`.

### Invoking a skill

**Explicitly** — type the slash command:

```
/ros2-node-creation
/ros2-lifecycle    add a managed node for the gripper bridge
/python-testing
```

**Implicitly** — just describe the task. Claude matches it to a skill:

```
Write a lifecycle node that owns the RC8 TCP connection
    → loads ros2-lifecycle + ros2-node-creation

The joint_states publisher drops messages under load
    → loads ros2-messaging
```

**By path** — when you want a specific one and nothing else:

```
Follow .claude/skills/ros2-control/SKILL.md and add a velocity
hardware interface for the Cobotta.
```

### Learning mode — `/robotics-mentor`

Every other skill exists to make Claude produce the work. This one exists to
make **you** produce it.

```
/robotics-mentor   why does my arm jerk at the start of every trajectory?
/robotics-mentor   I want to actually understand TF frame conventions
```

Claude switches to an expert-mentor stance: one question per turn, aimed at the
edge where your model stops being correct, and anything you get wrong is
explained through a concrete example — from your own code where possible,
otherwise from your robot or a canonical scenario — then handed back to you.

**You write every line that ends up in the repo.** When you're stuck, Claude
descends a five-rung hint ladder one rung per turn — region → symptom question →
concept → contract/signature → *a failing test you make pass*. It never writes
the implementation, the patch, or a "rough sketch you could adapt". Facts are
free, though: API signatures, return types, units, and build mechanics come back
immediately, because withholding a lookup is friction, not teaching.

It is **general robotics**, not scoped to this workspace: ROS 1/2 and non-ROS,
kinematics, control, state estimation, perception, planning, behaviour trees,
embedded and real-time, sim-to-real, RL. `references/probe-questions.md` inside
the skill carries question banks and the common misconceptions per domain.

| | |
| --- | --- |
| **Enter** | `/robotics-mentor` — the *only* way in. It never triggers on its own, no matter how much a question sounds like learning. |
| **Duration** | Stays on for the rest of the session, across follow-ups and topic changes. |
| **Exit** | "just tell me", "answer directly", "exit mentor" — then you get a full direct answer. These are treated as a decision and honoured immediately. |
| **Stuck ≠ exit** | "I don't get it" is struggle, not a request to leave. Claude makes the step *smaller* — shrinks the question, suggests an experiment, or gives the category of the answer — rather than folding. |
| **Auto-exit** | Claude breaks character by itself, and says so, for anything touching real hardware or safety (stated plainly and immediately — never Socratic about physical risk), pure lookups, or visible frustration. |

### ROS 2 core skills

| Skill | Use it when |
| ----- | ----------- |
| `ros2-node-creation` | New node (Py/C++) — `BaseNode`, dependency injection, QoS wiring |
| `ros2-lifecycle` | Anything owning a resource: sensor, actuator, hardware bridge |
| `ros2-messaging` | Pub/sub design, thread-safe buffers, message synchronisation |
| `ros2-service-action` | Service/action servers & clients backed by use cases |
| `ros2-launch-config` | Modular launch files, composition, parameter plumbing |
| `ros2-transforms` | TF2 broadcast/lookup without leaking `geometry_msgs` into domain |
| `ros2-diagnostics` | `diagnostic_updater`, frequency & liveliness monitoring |
| `ros2-bag` | Programmatic rosbag2 record / replay |
| `ros2-testing` | Unit (domain) / integration (node) / E2E (launch) test layout |
| `ros2-control` | Hardware interfaces, custom controllers, controller manager, URDF |

### Language & framework skills

| Skill | Use it when |
| ----- | ----------- |
| `python-patterns` | Writing/refactoring Python — idioms, PEP 8, type hints |
| `python-testing` | pytest, TDD, fixtures, mocking, parametrisation, coverage |
| `cpp-coding-standards` | Writing/reviewing C++ against the C++ Core Guidelines |
| `cpp-testing` | GoogleTest/CTest authoring, flaky-test diagnosis, sanitizers |
| `pytorch-patterns` | Training pipelines, model architectures, data loading |
| `ai-first-engineering` | Process/operating-model questions for AI-heavy teams |
| `content-engine` | Non-ROS: platform-native written content |

### Slash commands

`commands/ros2.md` → `/ros2` — reference card for `colcon`, `ros2`, `rqt`,
and the usual build/test/introspection one-liners.

---

## Agents

Sub-agents run in their own context with their own tool set (all on Opus)
and report back a summary. They are **off by default** — Claude works
inline unless you opt in.

### Opting in

Include a trigger word anywhere in your message:

* **`uab`** — *Use Agents for Building.* Activates the build/review agents.
* **`uat`** — *Use Agents for Testing.* Activates the run/test loop.

The opt-in applies to **that message only**. Repeat it to keep the
workflow going. A message may contain both. To suppress it, say
"skip the agents" or "no review".

```
uab  add an action server for MoveToJointGoal
     → clean-arch-architect first, then code-reviewer + cpp-reviewer after the edits

uat  ros2 launch denso_bringup robot.launch.py
     → uat-runner → uat-injector → uat-diagnoser → uat-fixer → re-run
```

### `uab` — build & review

| Agent | Fires when | Timing |
| ----- | ---------- | ------ |
| `clean-arch-architect` | New node/use case/port; topic vs service vs action; compose vs split | **Before** writing code |
| `code-reviewer` | Any source file edited | After the edit |
| `cpp-reviewer` | Any `.cpp/.hpp/.cc/.h` edited (in addition to `code-reviewer`) | After the edit |
| `python-reviewer` | Any `.py` edited (in addition to `code-reviewer`) | After the edit |
| `ros2-style-reviewer` | About to open a ROS 2 / Nav2 PR | **Before** the PR |
| `cpp-build-resolver` | C++ / CMake / linker build failure | On failure |
| `pytorch-build-resolver` | PyTorch train or inference crash | On failure |
| `ros2-runtime-diagnoser` | You paste a log, stack trace, or `~/.ros/log` dump | On report |

Conventions:

* **Reviews are batched** — once per completed set of edits, not per `Edit` call.
* **Trivial edits skip review** — docs, comments, whitespace.
* **One architect pass per feature**, not per file.

### `uat` — run & test loop

Driven by the main session, which passes each report to the next agent
and re-runs the runner after a fix.

| Step | Agent | What it does |
| ---- | ----- | ------------ |
| 1 | `uat-runner` | Sources the workspace, starts the command under test, reports the node/topic surface and log path |
| 2 | `uat-injector` | Sends the goal(s) — `topic pub`, `service call`, `action send_goal`, param set |
| 3 | `uat-diagnoser` | Read-only: watches topics/hz, lifecycle state, TF, logs; isolates root cause and names the fix skill |
| 4 | `uat-fixer` | Applies the minimal, layer-respecting fix; verifies it builds |
| 5 | `uat-runner` | Re-run to confirm |

Conventions:

* **Runner and injector ask** when the command or goal payload is missing —
  they never guess a package, executable, or message type.
* **Agents don't nest.** `uat-fixer` *names* an escalation target (e.g.
  `cpp-build-resolver`, `clean-arch-architect`); the main session spawns it,
  then resumes the loop.
* **Stop on PASS.** If `uat-diagnoser` reports PASS, the loop ends — the
  fixer does not run.

---

## Rules (always on)

No invocation needed; these constrain every response.

| File | Constrains |
| ---- | ---------- |
| `ros2_general.md` | Package naming, file layout, launch, params |
| `ros2_nodes.md` | Node design — lifecycle, callback groups, parameters |
| `ros2_communication.md` | Topic naming, QoS profiles, custom interfaces |
| `testing.md` | Unit / integration / launch coverage requirements |
| `robot_specific.md` | Robot-level overrides — **replace per project** |
| `colcon_build.md` | Workspace build standards and execution directory constraints |

The non-negotiables they encode:

* Domain code never imports `rclpy`, `rclcpp`, or any `*_msgs`. If it needs
  ROS, it isn't domain.
* Lifecycle by default for anything owning a resource.
* `declare_parameter` for every parameter — a silent `get_parameter` on an
  undeclared name is a bug.
* QoS matches semantics — sensor data best-effort, commands reliable,
  latched config transient-local.
* Tests run under `colcon test`; never `sleep(N)` to synchronise — use
  futures, conditions, or `launch_testing.ReadyToTest`.

---

## Adding your own

**A skill** — create `skills/<snake_case_name>/SKILL.md` with frontmatter:

```markdown
---
name: my_skill
description: One line. This is what Claude matches against, so be specific
             about when the skill applies.
---

# My Skill
...body: patterns, templates, do/don't...
```

The directory name is the slash command (`/my_skill`). Add a row to the
table in `CLAUDE.md` so it shows up in the session orientation.

Keep `SKILL.md` to what's needed *every* time the skill runs, and push bulky
lookup material into a `references/` subdirectory that the body points at, so
it's read only when relevant — `robotics-mentor/references/probe-questions.md`
is the example.

**A manual-only skill** — skill matching runs off `description`, so to stop one
auto-loading, lead the description with the prohibition instead of the topic:

```markdown
description: EXPLICIT INVOCATION ONLY. Do NOT load this skill by topic match —
             load it only when the user literally types /my_skill. <what it does>
```

That's heuristic on its own, so back it with a line in `CLAUDE.md` (always in
context) saying the skill is manual-only. `robotics-mentor` does both.

**An agent** — create `agents/<name>.md`:

```markdown
---
name: my-agent
description: When to use this agent, and what it returns.
tools: ["Read", "Grep", "Glob", "Bash"]
model: opus
---

You are ...
```

Give it the narrowest tool set that does the job — review agents should not
have `Write` or `Edit`. Then add it to the appropriate `uab`/`uat` routing
table in `CLAUDE.md`, or it will never be triggered.

---

## Settings

`settings.json` (checked in) sets `defaultMode: acceptEdits` and pre-allows
the routine ROS 2 toolchain — `colcon build/test`, `ros2 *`, `rosdep`, `vcs`,
`pytest`, `python3`, read-only `git`. It denies `sudo`, `docker`, `rm -rf`,
and reads of `.env` / `~/.ssh`. `git push` prompts.

`settings.local.json` is machine-local and untracked — put personal
allowances there rather than widening the shared file.
