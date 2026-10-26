# Build Scripts and Sanitizers for FFI Crates

Illustrative recipes for Step 05. Verify each against the installed
library versions before relying on it, and record the verified commands in
`STATUS.md`.

## build.rs with pkg-config and a version pin

```rust
// rust/crates/arche-ffi-pinocchio/build.rs
fn main() {
    println!("cargo::rerun-if-changed=cpp/shim.hpp");
    println!("cargo::rerun-if-changed=cpp/shim.cpp");
    println!("cargo::rerun-if-changed=src/lib.rs");
    println!("cargo::rerun-if-env-changed=PKG_CONFIG_PATH");
    println!("cargo::rerun-if-env-changed=CMAKE_PREFIX_PATH");

    // Pinocchio 3.x (Jazzy, hpp-fcl) and 4.x (Lyrical, coal) differ in API:
    // pin one major version per build.
    let lib = match pkg_config::Config::new()
        .atleast_version("4.0")
        .cargo_metadata(true)
        .probe("pinocchio")
    {
        Ok(lib) if lib.version.starts_with("4.") => lib,
        Ok(lib) => panic!("arche-ffi-pinocchio needs Pinocchio 4.x, found {}", lib.version),
        Err(e) => panic!(
            "Pinocchio not found via pkg-config ({e}). Source /opt/ros/<distro>/setup.bash \
             or set PKG_CONFIG_PATH."
        ),
    };

    cxx_build::bridge("src/lib.rs")
        .file("cpp/shim.cpp")
        .std("c++17")
        .includes(&lib.include_paths)
        .flag_if_supported("-Wall")
        .flag_if_supported("-Wextra")
        // match the legacy colcon Release build; never -ffast-math
        .opt_level(2)
        .compile("arche_ffi_pinocchio_shim");
}
```

Notes:
- Under ROS, `pkg-config` finds `.pc` files once the ROS setup is sourced
  (`/opt/ros/<distro>/lib/pkgconfig`). Document the expected environment
  in the crate's README and fail with a hint, as above.
- `panic!` in `build.rs` is the standard way to fail a build. The workspace
  `clippy::panic` lint does not apply to build scripts unless they are
  linted explicitly; add `#![allow(clippy::panic)]` with a reason if needed.
- Link only what the shim uses. Pinocchio pulls in its collision backend
  (hpp-fcl or coal); never link both in one binary.

## Feature-gating optional backends

```toml
# rust/crates/arche-cli/Cargo.toml (composition root)
[features]
default = []
pinocchio = ["dep:arche-ffi-pinocchio"]
ompl = ["dep:arche-ffi-ompl"]
```

CI cells without the C++ libraries build with default features only.

## AddressSanitizer / UBSan

Rust's `-Zsanitizer` needs a nightly toolchain. The workspace pins stable,
so run sanitizers in a **dedicated CI job** with an explicit override:

```bash
# Both sides instrumented: Rust via -Zsanitizer, C++ shim via CXXFLAGS.
export RUSTFLAGS="-Zsanitizer=address"
export CXXFLAGS="-fsanitize=address -fno-omit-frame-pointer"
export ASAN_OPTIONS="detect_leaks=1:abort_on_error=1"
cargo +nightly test -Zbuild-std --target x86_64-unknown-linux-gnu -p arche-ffi-pinocchio
```

- `-Zbuild-std` rebuilds std with the sanitizer; without it, false
  positives and missed reports are common.
- The vendor library itself is not instrumented (system package). ASan
  still catches out-of-bounds access on Rust-owned buffers written by the shim,
  use-after-free of shim objects and leaks of `UniquePtr`s.
- UBSan on the shim: `CXXFLAGS="-fsanitize=undefined -fno-sanitize-recover=all"`
  with a stable toolchain (link `-lubsan` via `cargo::rustc-link-lib=ubsan`
  in a `sanitize` feature).

Stable-toolchain fallback: valgrind.

```bash
cargo test -p arche-ffi-pinocchio --no-run
valgrind --error-exitcode=1 --leak-check=full \
  target/debug/deps/arche_ffi_pinocchio-<hash> --test-threads=1
```

Known noise: Pinocchio/Boost static initialisers report "still reachable"
blocks. Suppress them with a reviewed suppressions file, never with
`--errors-for-leak-kinds=none`.

## octomap double free (coal/fcl on Lyrical)

The legacy coal and fcl collision tests carry a workaround for an octomap
1.9/1.10 double free (`STATUS.md` §4.2 confirms it holds on Lyrical).
Expect the problem to reappear when
`arche-ffi-coal` links coal with octomap. Reproduce under ASan first,
then apply the same workaround as the C++ tests. Document it in the crate.

## CI layout for FFI crates

| Job | Toolchain | Runs |
|---|---|---|
| `ffi-linux` | pinned stable | ROS setup sourced, `cargo test -p arche-ffi-*` |
| `ffi-asan` | nightly (explicit) | ASan command above, FFI crates only |
| `check` (existing) | pinned stable | pure-Rust crates on Ubuntu + macOS, FFI crates excluded |
