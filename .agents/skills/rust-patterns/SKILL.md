---
name: rust-patterns
description: Idiomatic Rust (2024 edition) for writing, reviewing, or refactoring Rust code - ownership and borrowing, typed error handling (thiserror/anyhow), traits and generics, concurrency, async (tokio), unsafe policy, clippy. Use when writing or reviewing any .rs file or Cargo.toml.
origin: local (ECC-style; ECC ships rust-reviewer / rust-build-resolver agents but no Rust skill)
---

# Rust Patterns (Agent Skill)

Idioms and guardrails for modern Rust (edition 2024, stable toolchain) so code compiles cleanly under `cargo clippy -- -D warnings` and reads like the standard library.

## When to Use

- Writing new Rust crates, modules, or binaries
- Reviewing or refactoring Rust code (panics, `unwrap`, lifetimes, clones)
- Designing public APIs, error types, or trait hierarchies
- Adding concurrency (threads, channels, `Arc<Mutex<_>>`) or async (tokio)

### When NOT to Use

- Writing or fixing tests only → `rust-testing`
- C++ or Python code → `cpp-coding-standards` / `python-patterns`

## Cross-Cutting Principles

1. **Make invalid states unrepresentable** - enums and newtypes over flags and raw `String`/`f64`.
2. **Library code never panics on bad input** - return `Result`; `panic!`/`unwrap`/`expect` only for proven invariants (document why).
3. **Borrow by default, own when you must** - take `&str`, `&[T]`, `impl AsRef<Path>`; return owned values.
4. **Zero `unsafe` unless required** - put `#![forbid(unsafe_code)]` in crates that don't need it.
5. **Let clippy be the reviewer** - `cargo clippy --all-targets -- -D warnings` clean; consider `-W clippy::pedantic`.

## Project Setup

```toml
# Cargo.toml
[package]
name = "my_crate"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"

[lints.rust]
unsafe_code = "forbid"
missing_docs = "warn"

[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"
```

Commands:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets
cargo doc --no-deps
```

## Ownership & Borrowing

```rust
// DO: borrow inputs, return owned outputs
pub fn normalize(name: &str) -> String {
    name.trim().to_lowercase()
}

// DO: accept generic borrowed views
pub fn load(path: impl AsRef<std::path::Path>) -> std::io::Result<String> {
    std::fs::read_to_string(path)
}

// DON'T: take ownership you don't need / clone to silence the borrow checker
pub fn normalize_bad(name: String) -> String { name.clone().trim().to_lowercase() }
```

- Prefer iterators (`iter().map().filter().collect()`) over index loops.
- Use `Cow<'_, str>` when a function only sometimes allocates.
- Avoid explicit lifetimes unless elision fails; never `'static` to "fix" errors.

## Error Handling

Libraries: one typed error enum per module/crate with `thiserror`. Binaries: `anyhow::Result` with `.context()`.

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ParseError {
    #[error("line {line}: missing field `{field}`")]
    MissingField { line: usize, field: &'static str },
    #[error("line {line}: invalid number `{raw}`")]
    InvalidNumber { line: usize, raw: String, #[source] source: std::num::ParseFloatError },
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

pub fn parse_value(line: usize, raw: &str) -> Result<f64, ParseError> {
    raw.trim().parse().map_err(|source| ParseError::InvalidNumber {
        line,
        raw: raw.to_owned(),
        source,
    })
}
```

```rust
// binary
use anyhow::{Context, Result};

fn main() -> Result<()> {
    let cfg = std::fs::read_to_string("cfg.toml").context("reading cfg.toml")?;
    run(&cfg)?;
    Ok(())
}
```

Without dependencies, implement `std::fmt::Display` + `std::error::Error` (with `source()`) by hand.

### Anti-Patterns

- `unwrap()` / `expect()` on user input, I/O, or parsing in library code
- `Box<dyn Error>` / `String` as a library's public error type (callers can't match)
- Swallowing errors with `.ok()` or `let _ =` without a comment
- `panic!` for recoverable conditions

## Types, Traits & Generics

```rust
// Newtype for units / invariants
#[derive(Debug, Clone, Copy, PartialEq, PartialOrd)]
pub struct Radians(f64);

impl Radians {
    pub fn new(v: f64) -> Option<Self> { v.is_finite().then_some(Self(v)) }
    pub fn get(self) -> f64 { self.0 }
}

// Enum state machine instead of booleans
pub enum JointState { Idle, Moving { target: Radians }, Fault(String) }
```

- Derive `Debug` on all public types; `Clone, Copy, PartialEq, Eq, Hash, Default` where meaningful.
- Implement standard traits (`From`, `TryFrom`, `Display`, `FromStr`, `Iterator`) instead of ad-hoc methods.
- Prefer `impl Trait` in argument position for simple generics; `where` clauses for complex bounds.
- Use `#[must_use]` on functions whose result must not be ignored.
- Builders for structs with many optional fields; `#[non_exhaustive]` on public enums that may grow.

## Concurrency

```rust
use std::sync::{mpsc, Arc, Mutex};
use std::thread;

// Prefer message passing; scoped threads when borrowing
let data = vec![1, 2, 3];
thread::scope(|s| {
    s.spawn(|| println!("{}", data.len()));
});

// Graceful shutdown: drop the Sender, workers exit when recv() returns Err
let (tx, rx) = mpsc::channel::<Job>();
let rx = Arc::new(Mutex::new(rx));
// ... spawn workers that loop on rx.lock().unwrap().recv()
drop(tx); // signals shutdown
// join every JoinHandle in Drop
```

- Never hold a `MutexGuard` across a blocking call or `.await`.
- Handle `PoisonError` explicitly (`lock().map_err(..)`) in libraries, or document why `unwrap` is sound.
- `Arc<T>` for shared ownership, `Arc<Mutex<T>>`/`RwLock` only when shared mutation is necessary; atomics for counters.
- Implement `Drop` to join worker threads so no thread outlives its pool.

## Async (tokio)

- One runtime per binary (`#[tokio::main]`); libraries stay runtime-agnostic where possible.
- Never call blocking I/O in async code; use `tokio::task::spawn_blocking`.
- Use `tokio::select!` with a cancellation token / `broadcast` for shutdown.
- Bound channels (`mpsc::channel(n)`) to get back-pressure.

## Unsafe Policy

- `#![forbid(unsafe_code)]` by default.
- When unavoidable: smallest possible block, `// SAFETY:` comment stating the invariant, safe wrapper API, Miri test (`cargo +nightly miri test`).

## Performance

- Measure first (`cargo bench` / criterion); avoid premature `clone()` removal that hurts clarity.
- Pre-allocate (`Vec::with_capacity`), avoid `collect()` into a temporary just to iterate again.
- Prefer `&[T]` over `&Vec<T>`, `&str` over `&String`.

## Review Checklist

- [ ] `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test` pass
- [ ] No `unwrap`/`expect`/`panic!` on fallible input in library code
- [ ] Public error type is a matchable enum implementing `std::error::Error`
- [ ] No unnecessary `clone()`, `to_string()`, or owned parameters
- [ ] `unsafe` absent or justified with `// SAFETY:` and tested
- [ ] Threads joined / tasks awaited on shutdown; no guard held across blocking or `.await`
- [ ] Public items documented (`///`), with an example where useful
