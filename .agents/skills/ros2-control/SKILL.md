---
name: ros2-control
description: Implement or configure ros2_control hardware interfaces, controllers, controller manager, and URDF integration in C++. Use for plugin development, API migration, real-time data exchange, and hardware/controller testing.
---

# ros2_control

Keep control algorithms and device abstractions independent of ROS. Implement
framework lifecycle, interface conversion, and plugin registration in adapters;
wire dependencies at the application boundary.

## Establish the Supported API

Inspect the project's ROS distribution and installed `hardware_interface`,
`controller_interface`, and `realtime_tools` headers before writing overrides.
Preserve the project's compiler standard and supported distributions. Do not
copy signatures from another release or silently upgrade dependencies.

| Concern | Check in the installed version |
| --- | --- |
| Hardware initialization | `on_init(HardwareInfo)` versus `on_init(HardwareComponentInterfaceParams)`; call the corresponding base implementation first |
| Interface storage | Legacy exported handles versus framework-owned storage and `get_state` / `set_state` / `get_command` / `set_command` |
| Additional interfaces | Whether `export_unlisted_state_interface_descriptions()` and `export_unlisted_command_interface_descriptions()` are available |
| Loaned interfaces | Optional reads, typed writes, and return values that must be checked |
| Controller initialization | Positional arguments versus `ControllerInterfaceParams`; distinguish framework `init` from plugin `on_init` |
| Chainable controllers | Exported state/reference interface hooks and their ownership rules |
| Real-time handoff | Available buffer/box API, its blocking behavior, and copy/allocation costs |
| Publishing | Publisher construction and the installed `try_publish` or lock/publish API |

The [hardware initialization parameter reference](https://control.ros.org/rolling/doc/api/structhardware__interface_1_1HardwareComponentInterfaceParams.html)
describes the newer parameter object. Use documentation matching the target
release when implementing it; rolling documentation is not a compatibility
promise for an older deployment.

## Hardware Interfaces and Lifecycle

Choose `SystemInterface` for coupled multi-axis hardware, `ActuatorInterface`
for an actuator component, and `SensorInterface` for read-only measurements.

- Validate parameters, joint names, interface types, and required interfaces
  before activation. Report conversion and connection failures through the
  lifecycle callback's error contract; clean up partially acquired resources.
- Configure communication resources outside the real-time loop. Activate only
  after a valid initial state is available, and initialize commands according
  to the command mode: holding measured position differs from zero velocity or
  effort. Do not assume all devices expose position commands.
- Deactivate by making outputs safe and stopping resource users; cleanup releases
  connections and owned work. Support reconfigure/reactivate and error paths.
- With framework-owned storage, use its accessors instead of exporting pointers
  to a second backing array. Register additional interface descriptions through
  the supported hooks. With legacy handles, keep backing storage stable for
  every handle's lifetime.
- Treat absent optional readings and failed writes as explicit conditions.
  Match the declared interface type, including numeric literal types. Do not
  replace an unavailable measurement with a fabricated zero or discard a failed
  write just to satisfy `[[nodiscard]]`.

## Controllers and Real-Time Execution

- Declare or generate parameters, validate them during configuration, and request
  precisely named state and command interfaces. Map assigned interfaces by name;
  do not assume their order matches a configuration list.
- Define command dimensions, finite-value checks, stale-command behavior, and
  deactivation outputs. Translate and validate subscription input outside the
  update loop before publishing it to a thread-safe handoff.
- Preallocate messages, buffers, and interface keys/handles during configuration.
  Avoid dynamic allocation, string construction, blocking locks, filesystem or
  network I/O, and unbounded logging in `read`, `write`, and `update`.
- When available, `RealtimeThreadSafeBox` and `RealtimePublisher::try_publish`
  offer nonblocking handoff operations. Inspect overload semantics: a try-lock
  can avoid blocking while copying a dynamic vector still allocates. Choose
  bounded payloads and a deliberate policy when a handoff cannot complete.
- Preserve the installed API for older realtime_tools releases. Do not combine
  old publisher-locking examples with newer APIs in one implementation.
- Keep algorithm tests independent of controller-manager startup; integration
  tests must still exercise actual lifecycle and interface ownership.

## URDF and Controller Configuration

A `<ros2_control>` component declares a plugin, parameters, and named interfaces:

```xml
<ros2_control name="ExampleSystem" type="system">
  <hardware>
    <plugin>example_hardware/ExampleSystem</plugin>
  </hardware>
  <joint name="axis_joint">
    <command_interface name="position"/>
    <state_interface name="position"/>
    <state_interface name="velocity"/>
  </joint>
</ros2_control>
```

Use names from the actual robot description. Put deployment values in URDF/xacro,
YAML, or launch arguments rather than source constants. Keep joint, interface,
plugin, and controller names consistent across these files.

Choose standard controllers from those available in the installed release:
forward command controllers for supported direct commands, trajectory controllers
for time-parameterized motion, and broadcasters for observations. Check plugin
names and parameter schemas locally; defaults and deprecated aliases vary.
Set timing and safety constraints explicitly when the application relies on them.

Sequence loading, configuring, and activating from observed manager/hardware
readiness and current lifecycle state. Do not repeatedly configure an already
configured controller or use fixed launch delays to mask readiness races.

## Build, Export, and Install

Use imported CMake targets when provided by the installed dependencies. Export
public dependencies and use the same export-set name for installation and ament:

```cmake
# After defining example_hardware and resolving its dependencies:
pluginlib_export_plugin_description_file(hardware_interface hardware_plugins.xml)
install(TARGETS example_hardware
  EXPORT export_example_hardware
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)
install(DIRECTORY include/ DESTINATION include)
ament_export_targets(export_example_hardware HAS_LIBRARY_TARGET)
ament_export_dependencies(hardware_interface pluginlib rclcpp)
```

Declare matching dependencies in `package.xml`, register each class with
`PLUGINLIB_EXPORT_CLASS`, and ensure plugin XML names the actual library and base
class. For controllers, export the descriptor against `controller_interface`.

When using `generate_parameter_library`, link its generated target and use its
listener/schema validation. Include required generated targets in the appropriate
export set and verify installed generated headers are reachable by downstream
consumers. Do not assume the header installation layout from another release.

## Verification

- Load hardware through the installed `ResourceManager` API with a valid robot
  description; exercise lifecycle transitions and read/write cycles with known
  commands and observed state. Check return types against the installed headers.
- Initialize controllers with that release's parameter object or supported
  signature, configure, assign owned test interfaces, activate, and call update.
  Assert the actual lifecycle state; transition APIs may return state objects
  rather than callback return codes.
- Test missing/wrong interfaces, malformed parameters, unavailable measurements,
  stale commands, failed writes, safe deactivation, and reactivation as applicable.
- Verify plugin discovery and installed target consumption in an integration test.
  Use mock hardware for routine tests; real hardware execution needs an explicitly
  authorized command and operating scope.
- Run package tests through `colcon test` and inspect test results and test counts.
  Synchronize on futures or state conditions with deadlines, never fixed sleeps.
