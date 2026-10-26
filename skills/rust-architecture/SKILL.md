---
name: rust-architecture
description: Rust crate layering and public API design for a Clean Architecture robotics workspace (domain / contracts / implementations / adapters). Use when creating or changing a Rust crate, adding a dependency between crates, designing public types, traits, errors, plugin contracts or a static plugin registry, or porting a C++ interface to Rust.
---

# Rust Architecture and API Design

How to structure a Cargo workspace so that robotics domain code stays free
of ROS 2, Python and C++, and how to design public Rust APIs that are hard
to misuse. Written for Arche (`src/rust/crates/`), applicable to any layered
Rust robotics workspace.

## When to Use

- Creating a new crate or deciding which crate a type/trait belongs in
- Adding a dependency (internal or external) to a crate
- Designing public structs, enums, traits, error types or request/result types
- Porting a C++ class or interface (for example an `arche_base` contract) to Rust
- Designing plugin contracts, capability negotiation or a registry
- Reviewing a Rust PR for layering or API problems

### When NOT to Use

- Writing the `cxx` bridge itself → `rust-ffi`
- Writing tests, tolerances, golden files → `rust-testing`
- Measuring and comparing planners → `robotics-planning-benchmark`
- ROS 2 node design (even in Rust) → the `ros2_*` skills; this skill only
  decides that ROS code lives in the adapter crate

## Before You Start (Arche)

1. Read `src/arche/docs/migration/RUST_WORKSPACE.md` (crate map, allowed
   edges) and the matching row of `COMPATIBILITY_MATRIX.md` (what C++
   behaviour must be preserved, which parity oracle applies).
2. Read `.claude/rules/clean_architecture.md`. Its layer rules apply to Rust
   unchanged.
3. Check `STATUS.md` for the current step. Do not implement items planned
   for a later step.

## Layer Model

```text
adapters / composition roots   arche-ros2  arche-python  arche-cli  arche-benchmark
implementations                arche-kinematics  arche-planning  arche-trajectory | arche-ffi-*
contracts                      arche-plugin-api
domain                         arche-core ← arche-model ← arche-scene
```

| Layer | Contains | May depend on | Never |
|---|---|---|---|
| Domain | value types, frames, units, errors, models, scene | lower domain crates, small vetted math/serde crates | ROS 2, PyO3, `cxx`, vendor C++ types, I/O side effects beyond parsing |
| Contracts | traits, capability descriptors, registry | domain | implementations, adapters |
| Implementations | native algorithms, FFI-backed implementations | contracts, domain, own FFI bridge | other implementations' FFI crates, adapters |
| Adapters / roots | ROS 2, Python, CLI, benchmark runner | anything | being depended on by inner layers |

Rules:
- **Dependencies point inward only.** Cargo forbids cycles, but not
  inward-to-outward edges. In Arche those edges are checked by
  `rust/tools/check_layering.py` and `rust/deny.toml` `[bans]`. Update both when
  adding a crate.
- **Composition happens only in roots.** Only an adapter chooses between
  `arche-ffi-pinocchio` and a native kinematics implementation and passes
  `Box<dyn Kinematics>` / `Arc<dyn Kinematics>` inward.
- **One reason to exist per crate.** Create a crate when it has a consumer
  in the current step. Do not create empty speculative crates; record them
  as "proposed" in the workspace doc instead.

## Crate Checklist

- [ ] `Cargo.toml` inherits `version`, `edition`, `rust-version`,
      `license`, `repository`, `publish` from `[workspace.package]`
- [ ] `[lints] workspace = true` (never redefine lint levels per crate)
- [ ] external deps added under `[workspace.dependencies]`, referenced as
      `foo.workspace = true`; `cargo deny check` still passes
- [ ] crate-level `//!` docs: purpose, layer, what is *not* here, C++ parity source
- [ ] added to `ALLOWED` in `rust/tools/check_layering.py` and the crate map
- [ ] no `unsafe` (only `arche-ffi-*` may `#![allow(unsafe_code)]`)
- [ ] `STATUS.md` row updated with evidence (test names, commands)

## API Design Rules

### Types carry meaning

- **Newtypes for identifiers and units**: `FrameId`, `JointName`,
  `Seconds(f64)`, not bare `String`/`f64`. SI units throughout; put the unit
  in the doc comment, and in the name when ambiguous (`timeout_s`).
- **Make invalid states unrepresentable.** Validate in constructors and keep
  fields private where invariants exist (`q.len() == nq`, unit
  quaternion). C++ code that silently accepted bad input (unknown frame →
  identity, unknown base type → `Fixed`) must return `Err` in Rust. Record
  each such behaviour change as an ADR.
- **Enums over flags and strings.** `BaseType::{Fixed, PlanarSe2,
  FloatingSe3}`; keep the C++ wire value with an explicit `#[repr(u8)]` or a
  `to_wire()` fn when parity requires it.
- **`#[non_exhaustive]`** on public enums and on structs that will grow
  (errors, capabilities, results). Not on plain value types like `Pose`.

### Ownership and requests

- Requests are **immutable values**. Build them once, then pass `&Request`.
  Results are owned (`PlanResult`), never references into solver state.
- Take `&[f64]` / `&T` in, return owned data out. Avoid `&mut` output
  parameters copied from C++ style.
- Put the **seed, time budget and planner id in the request**. Never use a
  global RNG or wall-clock defaults hidden inside an implementation.
- Prefer `BTreeMap`/sorted `Vec` over `HashMap` wherever iteration order can
  reach output (determinism, golden tests).

### Errors

- One `#[non_exhaustive]` error enum per crate boundary, implementing
  `std::error::Error` + `Display`. Variants carry context (frame name,
  index, expected/actual sizes).
- Library code returns `Result`. No `unwrap`/`expect`/`panic!` outside tests.
  The workspace lints warn and CI turns warnings into errors.
- Keep distinct failure kinds distinct: *invalid input*, *infeasible*
  (no solution exists / not found in budget), *cancelled*, *timeout*,
  *backend failure*. A caller must be able to retry only what is retryable.
- When porting C++ status codes, write the mapping table into the error
  type's docs (`ErrorCode::kInvalidState` → `ArcheError::InvalidState`).

### Traits (plugin contracts)

- **Object-safe** traits used through `Box<dyn T + Send + Sync>`.
  Generic methods go into a separate extension trait or become a concrete type.
- Require `Send + Sync` for anything a server or executor may share across
  threads. Document whether methods may be called concurrently.
- Configuration is a **typed struct** passed at construction or to
  `configure(&Config) -> Result<(), E>`. No ROS node handles, no string bags.
- Long-running calls take a **cancellation token** (`&CancelToken` checked
  cooperatively) and a time budget, and return `Cancelled`/`Timeout`
  explicitly.
- Expose **capabilities** as data (`fn capabilities(&self) -> Capabilities`)
  instead of `supports_x()` booleans scattered over the trait, and instead of
  downcasting to a concrete type.
- See [references/plugin-registry.md](references/plugin-registry.md) for the
  static registry pattern (no cross-dylib trait objects).

### Feature flags

- Optional integrations (`serde`, a solver backend) are **additive** cargo
  features, off by default in domain crates. A feature must never change
  numerical results of default code paths.

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| `arche-core` imports `rclrs`/`r2r` message types | Conversions in `arche-ros2` (`From`/`TryFrom` there) |
| Public fn takes `nalgebra`/`cxx` types from a backend crate | Own domain types; convert at the boundary |
| `pub` fields on types with invariants | Private fields + validating constructor + getters |
| `Result<T, String>` / `Box<dyn Error>` in library APIs | Typed error enum |
| `downcast_ref::<PinocchioModel>()` to reach missing data | Add it to the trait/capabilities |
| Global singleton registry with life-before-main tricks | Explicit `Registry::new()` + `register(...)` in the composition root |
| Copying C++ getters/setters 1:1 | Rust value types; builders only for >4 optional fields |
| Hidden `Instant::now()`/`thread_rng()` inside algorithms | Clock/seed injected via request |

## Workflow for a Port (C++ → Rust)

1. Find the row in `COMPATIBILITY_MATRIX.md`; list the *must preserve*
   and *must change* items.
2. Write the public API as types + docs + `todo`-free signatures; review the
   layering before implementing.
3. Write parity tests first (`rust-testing`), using the C++ tolerance.
4. Implement; run `cargo fmt --check`, `clippy -D warnings`, tests, layering
   check, `cargo deny`.
5. Record behaviour changes as ADRs (`references/api-checklist.md` has the
   template) and update `STATUS.md` with evidence.

## References

- [references/api-checklist.md](references/api-checklist.md) — review
  checklist for public API PRs, plus the ADR template
- [references/plugin-registry.md](references/plugin-registry.md) — contract
  trait, capabilities, cancellation and static registry example
