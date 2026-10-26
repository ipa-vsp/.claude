---
name: rust-ffi
description: Safe Rust/C++ interop with the cxx crate for wrapping C++ robotics libraries (Pinocchio, coal, OMPL, ProxSuite) behind narrow, opaque, documented bridges. Use when creating or changing an arche-ffi-* crate, a C++ shim, a cxx bridge, a build.rs that compiles or links C++, Eigen/array transfer, or when reviewing unsafe code at the language boundary.
---

# Safe C++ FFI for Rust (cxx)

Pattern for keeping third-party C++ algorithms usable from Rust without
letting C++ types, exceptions or undefined behaviour leak into the safe
Rust API. Arche wraps Pinocchio, coal, OMPL and possibly ProxSuite this
way (`COMPATIBILITY_MATRIX.md` §4), one `arche-ffi-<lib>` crate per library.

## When to Use

- Creating an `arche-ffi-*` crate or adding functions to its bridge
- Writing the C++ shim (`cpp/*.hpp/.cpp`) that a bridge calls
- Writing or debugging `build.rs` that compiles C++ or links system libraries
- Passing matrices/vectors (Eigen) across the boundary
- Deciding `Send`/`Sync` for C++-backed types
- Reviewing any `unsafe` block

### When NOT to Use

- Pure-Rust crates (`unsafe` is denied there anyway) → `rust-architecture`
- Deciding *whether* to port or wrap: read `COMPATIBILITY_MATRIX.md`
  first; that decision is already made per component
- C++-only changes to the legacy colcon packages → `cpp-coding-standards`,
  `cpp-testing`

## The Three-Layer Sandwich

```text
 safe Rust API  (implements arche-plugin-api trait, domain types only)
       │  owns UniquePtr<ffi::Handle>, converts types, maps errors
 cxx bridge     (#[cxx::bridge] mod ffi — the only place C++ is declared)
       │  opaque types, rust::Slice / rust::Vec / rust::Str, Result<T>
 C++ shim       (arche_ffi::* — small, exception-safe, no templates exposed)
       │  #includes the vendor library
 vendor C++     (Pinocchio / coal / OMPL)
```

Rules:
1. **The vendor headers are included only in the shim `.cpp`.** The shim
   header the bridge includes declares opaque classes and plain functions.
   `pinocchio::Model`, `Eigen::*`, `std::vector`, `std::shared_ptr` never
   appear in the bridge.
2. **The `ffi` module is private** (`mod ffi`, not `pub mod`). The crate's
   public API is safe Rust built on domain types.
3. **Opaque handles, copied data.** C++ objects stay behind
   `UniquePtr<Handle>`; numbers cross as slices and are copied into Rust
   types on return. No Rust reference into C++ memory outlives the call.
4. **One library per crate**, with its own shim and version check. Shared
   helpers (error type, matrix transfer, build helpers) live in
   `arche-ffi-common`.

## `unsafe` Policy

- The workspace denies `unsafe_code`. An FFI crate adds at the crate root:
  ```rust
  #![allow(unsafe_code, reason = "cxx bridge to <lib>; see SAFETY comments")]
  ```
- Every `unsafe` block and `unsafe impl` has a `// SAFETY:` comment naming
  the invariant and who guarantees it (`undocumented_unsafe_blocks` lint).
- `cxx` makes most calls safe. If you write `unsafe` outside
  `unsafe impl Send/Sync`, question the design first.

## Errors, Exceptions and Panics

| Direction | Mechanism | Rule |
|---|---|---|
| C++ throws | declare the bridge fn as `-> Result<T>`; cxx catches `std::exception` and returns `Err(cxx::Exception)` | Every bridge fn whose shim can throw returns `Result`. The shim must not be `noexcept` if it can throw. An escaping exception from a non-`Result` fn **aborts**. |
| C++ error codes / bool | shim returns a status struct or throws | Prefer throwing a `std::runtime_error` with context in the shim; map in Rust |
| Rust panics in a callback called by C++ | cxx aborts the process | Callbacks (`extern "Rust"`) never panic: catch with `std::panic::catch_unwind` if they run arbitrary code, return `Result` |
| Rust → domain | `impl From<cxx::Exception> for BackendError` | Map to the crate's typed error. Keep `what()` text as context and never parse it for control flow. |

## Data Across the Boundary

- **Vectors:** `&[f64]` ↔ `rust::Slice<const double>` (zero-copy, borrowed
  for the call only); return `Vec<f64>` ↔ `rust::Vec<double>`.
- **Matrices:** pass `(data, rows, cols)` with **column-major** order
  (Eigen's default). Document the order on every function. In the shim, wrap
  with `Eigen::Map<const Eigen::MatrixXd>(ptr, rows, cols)`. Never store the
  map, and copy if the C++ side keeps it.
- **Sizes:** validate lengths in Rust *before* the call (`q.len() == nq`)
  and assert again in the shim. A wrong size in Eigen is UB, not an error.
- **Strings:** `&str` ↔ `rust::Str` (UTF-8, not NUL-terminated); C++ must
  not hold onto it.
- **Alignment:** `Eigen::Map` of a Rust slice must use unaligned maps (the
  default `Eigen::Unaligned`); fixed-size vectorizable Eigen types must not
  be built in place over Rust memory.
- Details and code: [references/cxx-bridge-patterns.md](references/cxx-bridge-patterns.md).

## Ownership and Thread Safety

- `UniquePtr<T>` for exclusively owned C++ objects; `SharedPtr<T>` only when
  C++ itself shares the object (for example an OMPL `SpaceInformationPtr`).
- Opaque C++ types are `!Send + !Sync` by default. Add
  `unsafe impl Send/Sync` only when the library documents it.
  Example: `pinocchio::Model` is read-only after construction (Sync), but
  `pinocchio::Data` is per-thread scratch. Wrap `Data` in a per-call or
  per-thread object, never in a shared `&self` path without a `Mutex`.
- Lifetimes between handles (a `Data` built from a `Model`) are expressed
  in the safe wrapper: the wrapper owns both, or holds `Arc<ModelHandle>`.
  Do not rely on C++ to keep the parent alive.

## Build and Link (`build.rs`)

- Use `cxx_build::bridge("src/lib.rs")` + `.file("cpp/shim.cpp")`,
  `.std("c++17")`. Include paths and link flags come from `pkg-config`
  (Pinocchio, coal, OMPL ship `.pc` files) or from `CMAKE_PREFIX_PATH` /
  `AMENT_PREFIX_PATH` under ROS.
- **Pin the vendor major version** in `build.rs`
  (`atleast_version` + an upper-bound check). Pinocchio 3 (Jazzy, hpp-fcl) and
  4.1 (Lyrical, coal) are API-incompatible. Emit a clear
  `cargo::error=`/panic message naming the found version.
- Emit `cargo::rerun-if-changed=` for every shim file and
  `cargo::rerun-if-env-changed=` for the prefix variables.
- Mirror the legacy C++ flags that affect numerics (`-O2/-O3`, no
  `-ffast-math`), so parity is not broken by compiler flags.
- FFI crates are Linux-first; gate the crate behind a workspace feature or
  CI cell if a platform lacks the library.
- See [references/build-and-sanitizers.md](references/build-and-sanitizers.md).

## Testing an FFI Crate

1. **Bridge smoke test:** construct, query one value, drop. Run under ASan
   and UBSan in CI (see references).
2. **Error path tests:** invalid URDF, wrong vector sizes, unknown frame.
   Each must return `Err` and must not abort.
3. **Parity tests** against the legacy C++ tests' expectations, using the
   same fixtures and tolerances (`rust-testing`, `arche-testkit`).
4. **Thread test** for any type marked `Send`/`Sync`: run N threads on a
   shared model and compare with the single-threaded result.
5. Miri cannot execute C++; do not claim Miri coverage for FFI paths.

## DO / DON'T

**DO**
- Keep the bridge small; add functions when a trait method needs them
- Copy at the boundary, and measure before optimising copies away
- Document units, frames and storage order on every bridge fn
- Run the bridge under sanitizers before the first parity test

**DON'T**
- Expose `ffi::*` types or `cxx::UniquePtr` in public signatures
- Pass Rust closures into long-lived C++ state (OMPL validity checkers) without
  a documented lifetime and a no-panic guarantee
- `unsafe impl Sync` because "it seems to work"
- Link two vendor major versions into one binary (Pinocchio 3 + 4, hpp-fcl + coal)
- Use `bindgen` on vendor headers; template-heavy C++ needs a hand-written shim

## References

- [references/cxx-bridge-patterns.md](references/cxx-bridge-patterns.md) —
  complete bridge + shim + safe wrapper example, matrix transfer, callbacks
- [references/build-and-sanitizers.md](references/build-and-sanitizers.md) —
  `build.rs` with pkg-config and version pin, ASan/UBSan/valgrind recipes, CI notes
