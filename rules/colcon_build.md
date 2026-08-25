---
description: Colcon Build Execution Rules and Workspace Standards
---

# Colcon Build Execution Standards

This rule file defines the mandatory execution directory constraints, standard workspace layout, build workflows, and recovery procedures for `colcon`.

## Mandatory Execution Directory Rules

- **ALWAYS execute `colcon` from the workspace root** (e.g., `/colcon_ws` or `${ROS_WORKSPACE_ROOT}`).
- **NEVER run `colcon build` inside the `src/` directory**, package folders, or any nested subdirectories.
- **Why this rule exists**:
  - Running `colcon` inside `src/` generates rogue `build/`, `install/`, and `log/` folders directly within your source code repository.
  - This pollutes git tracking, breaks overlay sourcing (`source install/setup.bash`), causes corrupted CMake cache references, and leads to difficult-to-diagnose build errors.

## Workspace Layout Standards

```
colcon_ws/                  # Workspace Root (EXECUTE ALL colcon commands HERE)
├── src/                    # Source Directory (NEVER run colcon commands inside here)
│   ├── robot_core/
│   │   ├── package.xml
│   │   └── CMakeLists.txt
│   └── robot_interfaces/
│       ├── package.xml
│       └── CMakeLists.txt
├── build/                  # Build artifacts directory (generated at workspace root)
├── install/                # Installation overlay directory (generated at workspace root)
└── log/                    # Execution logs (generated at workspace root)
```

## Standard Build Commands

All commands below assume the current working directory is the **workspace root**.

### Standard Build with Symlinks
```bash
colcon build --symlink-install
```
> Symlink install links Python scripts, launch files, and configurations without requiring a rebuild on script changes.

### Selected Package Build
```bash
# Build only the specified package(s)
colcon build --symlink-install --packages-select <pkg_name>

# Build a package and all of its dependencies
colcon build --symlink-install --packages-up-to <pkg_name>
```

### Build with Real-Time Output & Debugging
```bash
# Stream compiler and test output directly to the terminal
colcon build --symlink-install --event-handlers console_direct+

# Build with CMake export compile commands (for IDE/clangd support)
colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

# Limit parallel workers (for memory-constrained systems)
colcon build --symlink-install --parallel-workers 4
```

## Post-Build Environment Setup

After a successful build, source the overlay from the workspace root:

```bash
source install/setup.bash
```

## Workspace Clean & Recovery Procedures

### Clean Build Artifacts (from Workspace Root)
```bash
# Clean entire workspace build artifacts
rm -rf build/ install/ log/

# Clean a specific package only
rm -rf build/<pkg_name> install/<pkg_name>
```

### Accidental Execution Recovery (Cleaning `src/` Contamination)
If `colcon build` was accidentally executed inside `src/` or a subpackage:

```bash
# 1. Identify misplaced build, install, or log directories in src/
find src/ -maxdepth 3 -type d \( -name "build" -o -name "install" -o -name "log" \)

# 2. Remove misplaced directories from src/
find src/ -maxdepth 3 -type d \( -name "build" -o -name "install" -o -name "log" \) -exec rm -rf {} +

# 3. Return to workspace root and rebuild cleanly
colcon build --symlink-install
```

## AI Agent & Automation Guidelines

- **Working Directory Verification**: When proposing or executing shell commands that invoke `colcon`, always verify that the working directory (`cwd`) is the workspace root containing `src/`.
- **Pre-execution Check**: Never prefix colcon commands with `cd src && ...`. If navigating directories, ensure you return to the root before running `colcon`.