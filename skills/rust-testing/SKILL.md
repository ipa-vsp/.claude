---
name: rust-testing
description: Use when writing/updating/fixing Rust tests - cargo test unit/integration/doc tests, test layout, proptest property tests, mockall mocks, coverage (cargo llvm-cov), and diagnosing failing or flaky tests.
origin: local (ECC-style)
---

# Rust Testing (Agent Skill)

Agent-focused testing workflow for Rust crates with `cargo test`.

## When to Use

- Writing new Rust tests or fixing failing ones
- Designing unit / integration / doc-test coverage for a crate
- Adding property tests, mocks, or coverage gates
- Investigating flaky or order-dependent tests

### When NOT to Use

- Implementing features without test changes → `rust-patterns`
- C++ or Python tests → `cpp-testing` / `python-testing`

## Core Concepts

- **TDD loop**: red → green → refactor.
- **Unit tests** live next to the code in `#[cfg(test)] mod tests` and may test private items.
- **Integration tests** live in `tests/*.rs`, each file a separate crate using only the public API.
- **Doc tests** in `///` examples are compiled and run - keep them correct.
- **Determinism**: no sleeps, no wall-clock, no shared global state between tests.

## Layout

```
my_crate/
├── Cargo.toml
├── src/
│   ├── lib.rs          # #[cfg(test)] mod tests { ... }
│   └── parser.rs
└── tests/
    ├── common/mod.rs   # shared helpers (not a test target)
    └── parser_api.rs
```

## Code Examples

### Unit test

```rust
pub fn clamp(v: f64, lo: f64, hi: f64) -> f64 { v.max(lo).min(hi) }

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clamps_above_upper_bound() {
        assert_eq!(clamp(5.0, 0.0, 1.0), 1.0);
    }
}
```

### Testing errors (match the variant, not the message)

```rust
#[test]
fn missing_field_is_reported_with_line() {
    let err = parse("name=\n").unwrap_err();
    assert!(matches!(err, ParseError::MissingField { line: 1, .. }), "got {err:?}");
}
```

### Tests returning `Result`

```rust
#[test]
fn parses_valid_input() -> Result<(), Box<dyn std::error::Error>> {
    let cfg = parse("rate=10\n")?;
    assert_eq!(cfg.rate, 10.0);
    Ok(())
}
```

### Table-driven tests

```rust
#[test]
fn normalizes_names() {
    let cases = [("  Foo ", "foo"), ("BAR", "bar"), ("", "")];
    for (input, expected) in cases {
        assert_eq!(normalize(input), expected, "input: {input:?}");
    }
}
```

### Property test (proptest)

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn clamp_stays_in_range(v in any::<f64>().prop_filter("finite", |x| x.is_finite())) {
        let r = clamp(v, -1.0, 1.0);
        prop_assert!((-1.0..=1.0).contains(&r));
    }
}
```

### Mock a trait (mockall)

```rust
#[cfg_attr(test, mockall::automock)]
pub trait Clock { fn now_ms(&self) -> u64; }

#[test]
fn times_out_after_deadline() {
    let mut clock = MockClock::new();
    clock.expect_now_ms().return_const(5_000u64);
    assert!(is_expired(&clock, 1_000));
}
```

Prefer hand-written fakes for stateful collaborators; inject time and I/O through traits.

### Concurrency tests without sleeps

```rust
use std::sync::mpsc;
use std::time::Duration;

#[test]
fn worker_processes_job() {
    let (done_tx, done_rx) = mpsc::channel();
    let pool = Pool::new(2);
    pool.execute(move || done_tx.send(42).unwrap());
    // bounded wait on a signal, not a fixed sleep
    assert_eq!(done_rx.recv_timeout(Duration::from_secs(5)).unwrap(), 42);
}
```

## Running Tests

```bash
cargo test                          # all unit, integration, doc tests
cargo test parser::                 # filter by path
cargo test -- --nocapture           # show println!
cargo test -- --test-threads=1      # diagnose shared-state flakiness
cargo test --doc                    # doc tests only
cargo nextest run                   # faster runner, per-test processes (if installed)
```

## Coverage

```bash
cargo install cargo-llvm-cov
cargo llvm-cov --all-targets --fail-under-lines 80
cargo llvm-cov --html               # target/llvm-cov/html
```

## Flaky Tests Guardrails

- Never `thread::sleep` to synchronize; use channels, `Barrier`, `Condvar`, or `recv_timeout`.
- Use `tempfile::tempdir()` for filesystem tests; never write to fixed paths.
- No dependence on test order or global statics; tests run in parallel by default.
- Seed randomness (`proptest` persists failures in `proptest-regressions/` - commit them).

## Best Practices

### DO

- Name tests after behavior (`rejects_negative_rate`), one behavior per test
- Assert on error variants with `matches!`, not on `Display` strings
- Keep integration tests on the public API only
- Run `cargo clippy --all-targets` so test code is linted too

### DON'T

- `#[ignore]` a flaky test without an issue reference
- `unwrap()` in helpers without context - use `expect("why")` in tests
- Test private implementation details from integration tests
