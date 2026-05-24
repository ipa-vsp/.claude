# ROS 2 Clean Architecture Project — Claude Context

This project is set up with **Claude Skills**, **sub-agents**, and
**rules** to facilitate ROS 2 development following **Clean
Architecture** principles. This file is the persistent orientation
note Claude reads on every session; deep content lives in `skills/`,
`rules/`, `agents/`, and `commands/`.

## Project layout

A Clean Architecture package follows:

```
src/<pkg>/<pkg>/
├── domain/           # entities, value objects, ports (no ROS deps)
├── application/      # use cases (depends only on domain)
├── infrastructure/   # rclpy / rclcpp nodes, TF, repositories
└── presentation/     # CLI, launch entrypoints
```

For C++ the same separation lives under `include/<pkg>/<layer>/` and
`src/<layer>/`.

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
| `pytorch-patterns`     | Training pipelines, model architectures, data loading |
| `content-engine`       | Platform-native content systems (non-ROS, general use) |

To use a skill, reference its file (e.g.
`.claude/skills/ros2_node_creation/SKILL.md`).

## Sub-agents

| Agent | When to use |
|-------|-------------|
| `clean-arch-architect` | **Before** writing ROS 2 code — node vs use case, topic vs service vs action, compose vs split, where a new port belongs. Returns an architectural recommendation with trade-offs, not code. |
| `ros2-style-reviewer`  | **Before** opening a ROS 2 PR — Clean Architecture, lifecycle, QoS, pluginlib, tests, build manifests. Returns a punch list with `file:line` anchors. |
| `code-reviewer`        | After any code change — general quality, security, maintainability review. MUST be used after edits. |
| `cpp-reviewer`         | After any C++ change — memory safety, modern C++ idioms, concurrency, performance. MUST be used for C++. |
| `python-reviewer`      | After any Python change — PEP 8, Pythonic idioms, type hints, security, performance. MUST be used for Python. |
| `cpp-build-resolver`   | When a C++ / CMake / linker build fails — surgical fixes, minimal changes. |
| `pytorch-build-resolver` | When PyTorch training or inference crashes — tensor shape, device, gradient, DataLoader, AMP issues. |

## Rules

| Rule file                | What it constrains |
| ------------------------ | ------------------ |
| `clean_architecture.md`  | Layer dependency rules — who may import what |
| `ros2_general.md`        | Project-wide ROS 2 conventions (naming, layout, launch, params) |
| `ros2_nodes.md`          | Node design — lifecycle, callback groups, parameters |
| `ros2_communication.md`  | Topic naming, QoS profiles, custom interfaces |
| `testing.md`             | Unit / integration / launch test coverage requirements |
| `robot_specific.md`      | Robot-level overrides — replace per project |

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
