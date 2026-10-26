# Public API Review Checklist

Use on every PR that adds or changes a `pub` item in a domain, contract
or implementation crate.

## Layering

- [ ] Crate's new dependencies are allowed by `rust/tools/check_layering.py`
      and `deny.toml` (run both)
- [ ] No ROS 2, PyO3, `cxx` or vendor C++ type appears in a public signature
      of a non-adapter crate
- [ ] No backend crate's math types leak through the domain API (convert at
      the boundary)

## Types

- [ ] Identifiers and quantities use newtypes or documented SI units
- [ ] Invariants enforced in constructors; fields private where needed
- [ ] Public enums/growing structs are `#[non_exhaustive]`
- [ ] `Debug` implemented on every public type (`missing_debug_implementations`)
- [ ] `Clone`/`Copy`/`PartialEq`/`Eq`/`Hash` derived only where semantically
      right (no `Eq` on float types; no `Copy` on large arrays)
- [ ] Serialization, if any, is behind a `serde` feature and is
      deterministic (sorted maps, stable field order)

## Behaviour

- [ ] Fallible operations return a typed `Result`; error variants carry context
- [ ] No panics in library paths (`unwrap`, `expect`, indexing that can fail,
      `as` casts that truncate)
- [ ] Seeds, time budgets and clocks are inputs, not hidden globals
- [ ] Cancellation is cooperative and its latency is documented
- [ ] Thread-safety stated: `Send + Sync` bounds and whether `&self` methods
      may run concurrently

## Parity and docs

- [ ] Every public item has a doc comment with units and frames
- [ ] Doc example compiles (doctest) for the main entry points
- [ ] Differences from the C++ behaviour recorded as an ADR
- [ ] `STATUS.md` updated with test evidence, not design claims

---

## ADR template

Store as `src/arche/docs/migration/adr/NNNN-short-title.md`.

```markdown
# NNNN — <decision in one line>

* Status: proposed | accepted | superseded by NNNN
* Step: <implementation.md step number>
* Date: YYYY-MM-DD

## Context
What C++ behaviour or constraint forces a decision (cite file:line or the
INVENTORY / COMPATIBILITY_MATRIX row).

## Decision
What the Rust API does. Be concrete (types, error variants, defaults).

## Consequences
* Behaviour change visible to users / configs / ROS clients
* Parity impact: which oracle changes and how the test accounts for it
* Migration note for callers

## Alternatives considered
Each with the reason it was rejected.
```
