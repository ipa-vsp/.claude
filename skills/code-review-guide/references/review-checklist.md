# Review Checklist (ordered by consequence)

Work top-down and stop when the budget is spent — an unfinished tier-1 pass beats a
complete tier-4 pass. Anything not blocking goes out labeled as `suggestion:` or
`nit:`.

## Contents
- Tier 0 — Intent
- Tier 1 — Correctness and security (blocking)
- Tier 2 — Design that's hard to reverse
- Tier 3 — Tests
- Tier 4 — Clarity
- Tier 5 — Style (don't)
- AI-written code: extra passes
- Diffs that need a conversation, not comments
- Verdict

## Tier 0 — Intent

- What problem does this solve? Findable in one sentence from the PR/issue/spec.
- Does the change actually solve it, or an adjacent easier one?
- Is anything in the diff unrelated to that problem? Unrelated changes hide
  regressions and make reverts dangerous — ask for a split.
- Is there a simpler change that solves the same problem? Ask, don't assert.

## Tier 1 — Correctness and security (blocking)

- Wrong results on the happy path — read the logic, don't pattern-match it.
- Boundaries: empty, one, null/None, max length, zero, negative, duplicate,
  concurrent, first run, retry of a partial run.
- Errors: is every failure either handled or propagated? A bare catch that logs and
  continues turns an outage into silent corruption.
- Resource lifetime: files/connections/locks closed on the error path too.
- Concurrency: shared mutable state, check-then-act races, non-idempotent retries.
- Untrusted input reaching a query, a shell, a path, a template, or a deserializer.
- AuthN/AuthZ: is the permission check on the server side of the boundary, and does
  it cover the new route/field/parameter?
- Secrets, tokens, PII in code, logs, error messages, or URLs.
- Data migrations: reversible? Safe if it half-runs? Safe while old code is still
  serving traffic during deploy?
- Money and quantities: rounding, currency units, float where decimal is required.
- Dependencies added: needed, maintained, licensed compatibly, and pinned.

## Tier 2 — Design that's hard to reverse

Blocking when the cost of changing it later is high; a suggestion otherwise.

- Public API / schema / event shape / file format — these outlive the code.
- Coupling introduced across a module boundary that was previously clean.
- State that now lives in two places and can disagree.
- Abstraction added for one caller (premature) or duplicated logic that has already
  drifted twice (under-abstracted).
- Backward compatibility for existing callers, stored data, and in-flight requests.
- Failure behavior of the whole feature: what does the user see when the dependency
  is down?

## Tier 3 — Tests

- Do the tier-1 risks have a test? Untested tier-1 code is a blocking comment.
- Does the test assert observable behavior, or restate the implementation?
- Would the test fail if the bug were reintroduced? If it can't fail, it isn't a test.
- Are the boundary cases from tier 1 covered, or only the happy path?
- Mocked so thoroughly that nothing real is exercised?
- Deleted or skipped tests in the diff — always ask why.

## Tier 4 — Clarity

- Names that say what the thing is, especially booleans and units (`timeout_ms`).
- A comment where the code can't explain *why* — not restating *what*.
- Dead code, commented-out blocks, leftover debug output, stray TODOs with no owner.
- Function doing three jobs at three levels of abstraction.

## Tier 5 — Style (don't)

Formatting, import order, quote style, line length, trailing commas. If it can be
enforced by a tool, it is not review feedback — it's a missing tool. Open that PR
instead.

## AI-written code: extra passes

Confident prose, specific wrongness. Check for:

- **APIs that don't exist**: methods, flags, config keys, env vars invented by
  analogy. Verify against the installed version, not memory.
- **Swallowed errors**: broad catch, log-and-continue, default value returned on
  failure so the caller can't tell.
- **Edge cases that look handled**: guard present but off by one, condition
  inverted, timezone assumed, empty treated as missing.
- **Tests written against the implementation**: they pass with the bug in place, and
  were written after the code by the same generator.
- **Unexplained constants**: timeouts, limits, retry counts nobody chose.
- **Plausible-but-unused scaffolding**: config options, hooks, and abstraction layers
  no caller touches. Grep for callers, then delete.
- **Copied conventions from elsewhere**: patterns from another framework or from an
  older version of this repo that no longer apply here.

Rule that overrides tempo: never approve a diff you don't understand.

## Diffs that need a conversation, not comments

Stop reviewing and go talk when:
- you're past ~10 substantive comments;
- two or more comments are really the same structural objection;
- the diff is large enough that you're skimming;
- the right fix is "this shouldn't exist" or "this belongs in another layer".

Say what you'd block on, offer to pair, and don't leave forty inline notes behind.

## Verdict

State three things, always:
1. **Approve / approve-with-suggestions / changes requested** — pick one.
2. **What you actually reviewed**, and what you didn't.
3. **The blocking list**, numbered, or "nothing blocking".
