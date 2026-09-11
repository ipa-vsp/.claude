---
name: isaaclab
description: Guide and catalog for NVIDIA Isaac Lab simulation and RL workflows. Routes to specialized sub-skills in ./skills/ for environment creation, sensors/actuators, physics backends (PhysX/Newton), RL training, and debugging.
---

# Isaac Lab Skill

This skill provides an overarching guide and routing mechanism for NVIDIA Isaac Lab. It references the modular, repo-owned skills located in the [`skills/`](skills/) folder.

## When to Activate

- Creating, configuring, or debugging Isaac Lab environments (manager-based or direct)
- Training RL agents (RL-Games, RSL-RL, SKRL, SB3) or setting up multi-GPU distributed training
- Configuring robot assets, sensors (cameras, contact sensors, raycasters), and actuators
- Implementing domain randomization, curriculum, or event terms
- Migrating tasks from Isaac Gym or Isaac Lab 2.x to 3.x
- Selecting physics backends (PhysX vs. Newton) and preparing assets for Newton
- Troubleshooting Isaac Lab installation, Python environments, and rendering

## Sub-Skills Directory: [`skills/`](skills/)

Detailed, task-specific instructions and workflows are located in the [`skills`](skills/) directory. When addressing a specific Isaac Lab task, navigate directly to the corresponding sub-skill's `SKILL.md`:

### User Skills ([`skills/user/`](skills/user/))

| Sub-Skill | Path | Description |
| :--- | :--- | :--- |
| **Install Isaac Lab** | [`skills/user/install-isaac-lab/SKILL.md`](skills/user/install-isaac-lab/SKILL.md) | Install via uv, binaries, source build, wheels, or Docker across Linux and Windows |
| **Create Environments** | [`skills/user/create-environments/SKILL.md`](skills/user/create-environments/SKILL.md) | Build complete manager-based and direct RL environments from task requirements |
| **Convert Direct to Manager** | [`skills/user/convert-direct-to-manager/SKILL.md`](skills/user/convert-direct-to-manager/SKILL.md) | Convert validated direct Isaac Lab environments into manager-based task configurations |
| **Train RL Agents** | [`skills/user/train-rl-agents/SKILL.md`](skills/user/train-rl-agents/SKILL.md) | Configure and run RL training workflows (RSL-RL, RL-Games, SKRL, SB3) |
| **Train Multi-GPU** | [`skills/user/train-multi-gpu/SKILL.md`](skills/user/train-multi-gpu/SKILL.md) | Launch and debug multi-GPU and multi-node RL training |
| **Debug RL Training** | [`skills/user/debug-rl-training/SKILL.md`](skills/user/debug-rl-training/SKILL.md) | Diagnose RL reward curves, task metrics, and checkpoint issues |
| **Sensors & Actuators** | [`skills/user/use-sensors-actuators/SKILL.md`](skills/user/use-sensors-actuators/SKILL.md) | Integrate sensors (contact, camera, raycaster) and actuator models |
| **Domain Randomization** | [`skills/user/domain-randomization-events/SKILL.md`](skills/user/domain-randomization-events/SKILL.md) | Implement fixed/adaptive domain randomization through event & curriculum terms |
| **Manipulation Tasks** | [`skills/user/plan-manipulation-tasks/SKILL.md`](skills/user/plan-manipulation-tasks/SKILL.md) | Stage manipulation tasks through scene, reset, action, reward, and behavior gates |
| **Diagnose Joint Poses** | [`skills/user/diagnose-joint-poses/SKILL.md`](skills/user/diagnose-joint-poses/SKILL.md) | Measure and correct robot initial joint poses from semantic or visual requests |
| **Select Backends** | [`skills/user/select-backends/SKILL.md`](skills/user/select-backends/SKILL.md) | Choose and validate PhysX, Newton, and backend-specific task presets |
| **Use Presets** | [`skills/user/use-presets/SKILL.md`](skills/user/use-presets/SKILL.md) | Define and use preset configurations for multi-backend and variant-rich tasks |
| **Prepare Assets for Newton** | [`skills/user/prepare-assets-for-newton/SKILL.md`](skills/user/prepare-assets-for-newton/SKILL.md) | Prepare assets for Newton and migrate PhysX-authored assets |
| **Sim-to-Sim Transfer** | [`skills/user/isaaclab-transferring-policies-sim-to-sim/SKILL.md`](skills/user/isaaclab-transferring-policies-sim-to-sim/SKILL.md) | Validate bidirectional PhysX/Newton policy transfer and diagnose transfer gaps |
| **Migrate from Isaac Gym** | [`skills/user/migrate-from-isaac-gym/SKILL.md`](skills/user/migrate-from-isaac-gym/SKILL.md) | Migrate Isaac Gym tasks, assets, and training workflows to Isaac Lab |
| **Migrate 2.x to 3.x** | [`skills/user/migrate-2x-to-3x/SKILL.md`](skills/user/migrate-2x-to-3x/SKILL.md) | Upgrade Isaac Lab 2.x projects to Isaac Lab 3.0 |
| **Setup Troubleshooting** | [`skills/user/setup-troubleshooting/SKILL.md`](skills/user/setup-troubleshooting/SKILL.md) | Route installation, verification, and setup issues to official solutions |

### Developer Skills ([`skills/developer/`](skills/developer/))

| Sub-Skill | Path | Description |
| :--- | :--- | :--- |
| **PR Workflow** | [`skills/developer/pr-workflow/SKILL.md`](skills/developer/pr-workflow/SKILL.md) | Isaac Lab PR, commit, changelog, and validation conventions |
| **Coding Style** | [`skills/developer/coding-style/SKILL.md`](skills/developer/coding-style/SKILL.md) | Isaac Lab coding style, docstrings, type hints, and API design conventions |
| **Changelog Fragments** | [`skills/developer/changelog-fragments/SKILL.md`](skills/developer/changelog-fragments/SKILL.md) | Add and validate package changelog fragments |
| **Environment Docs** | [`skills/developer/isaaclab-updating-environment-docs/SKILL.md`](skills/developer/isaaclab-updating-environment-docs/SKILL.md) | Update environment docs and galleries |

## Catalog & Discovery

For details on the discovery mechanisms, refer to [`skills/README.md`](skills/README.md).

## Common Import Paths

| Concept | Import path |
| :--- | :--- |
| Direct RL environment config | `from isaaclab.envs import DirectRLEnvCfg` |
| Direct multi-agent environment config | `from isaaclab.envs import DirectMARLEnvCfg` |
| Manager-based RL environment config | `from isaaclab.envs import ManagerBasedRLEnvCfg` |
| Event term config | `from isaaclab.managers import EventTermCfg as EventTerm` |
| Scene entity config | `from isaaclab.managers import SceneEntityCfg` |
| Preset config | `from isaaclab_tasks.utils import PresetCfg` |
| Simulation config | `from isaaclab.sim import SimulationCfg` |
| PhysX physics config | `from isaaclab_physx.physics import PhysxCfg` |
| Newton physics config | `from isaaclab_newton.physics import NewtonCfg` |
| Base contact sensor config | `from isaaclab.sensors import ContactSensorCfg` |
| PhysX contact sensor config | `from isaaclab_physx.sensors import ContactSensorCfg as PhysXContactSensorCfg` |
| Newton contact sensor config | `from isaaclab_newton.sensors import ContactSensorCfg as NewtonContactSensorCfg` |
| Ray caster config | `from isaaclab.sensors import RayCasterCfg` |
| Tiled camera config | `from isaaclab.sensors import TiledCameraCfg` |
| Implicit actuator config | `from isaaclab.actuators import ImplicitActuatorCfg` |
| Core schema fragments and base cfgs | `from isaaclab.sim import schemas` |
| PhysX schema cfgs | `from isaaclab_physx.sim import schemas as physx_schemas` |
| Newton schema cfgs | `from isaaclab_newton.sim import schemas as newton_schemas` |