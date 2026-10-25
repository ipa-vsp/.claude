---
name: code-review-guide
description: >-
  Reviews someone's code, and handles feedback on yours — intent first, issues
  ranked by consequence, blocking vs non-blocking labeled. Use for "review
  this code", "review my PR", "look at this diff", or "how should I respond to this
  review comment".
license: MIT
metadata:
  brand: How to AI by Ruben Hassid
  protocol: howtoai-v1
  source: obra/superpowers (requesting-code-review, receiving-code-review)
  source-sha: 44c9b2d
  source-license: MIT
  upgraded: "2026-08"
  claude-ai-description: >-
    Review a diff or PR, and handle feedback on yours. Intent first, issues ranked by
    consequence, blocking vs non-blocking labeled, replies that move the PR forward.
---

# Code Review

Two directions, one job: get the code right without burning the person. Reviewing
is mostly prioritization — everything you flag costs the author a round-trip, so
spend that cost on what actually has consequences. Receiving is mostly separation —
the signal is in the comment, the sting is in your head, and only one of them is
about the code.

## Reviewing

### 1. Read the intent before the diff

Find what problem this solves — the issue, the PR description, the spec, the
conversation. If you can't state it in one sentence, ask before reviewing.

A technically clean diff that solves the wrong problem is the most expensive miss
in review, because every line comment you wrote is wasted and the real objection
arrives a week later. Judge the change against the problem first, the codebase
second, your preferences never.

### 2. Rank by consequence, then stop early

| Tier | What | Default label |
|---|---|---|
| 1 | Correctness, data loss, security, auth, money | blocking |
| 2 | Design that's hard to reverse: API shape, schema, coupling, concurrency | blocking if it locks in, else suggestion |
| 3 | Test coverage of the risky paths (not coverage %) | suggestion, blocking when tier 1 is untested |
| 4 | Naming, structure, readability | suggestion |
| 5 | Formatting, import order, quote style | don't comment — that's a linter's job |

Full pass, ordered and with the AI-code additions: `references/review-checklist.md`.
`scripts/review_scope.py` buckets a diff by consequence before you start reading.

### 3. Label blocking vs non-blocking on every comment

Unlabeled feedback stalls PRs for days: the author can't tell what's required, so
they either do everything or guess. Prefix every comment — `blocking:`,
`suggestion:`, `question:`, `nit:` (non-blocking by definition), `praise:`. If your
review has no blocking comments, say "approving — the rest are optional" out loud.

### 4. Comment on the code, and mean the praise

Address the change, not the author's judgment: "this drops the error" beats "you
forgot". And call out what's genuinely good and specific — the well-chosen
boundary, the test that would have caught the last outage. Generic "nice work"
reads as filler; accurate praise is what makes the blocking comments land.

Wording that models the tone for each comment type: `references/comment-templates.md`.

### 5. Know when to stop reviewing and go talk

Past roughly ten substantive comments, stop writing comments. That volume means
the design conversation should have happened before the code was written, and no
review thread recovers it. Say that, name the two or three structural issues, and
pair or call instead. Same move when the diff is too large to hold in your head —
review what you can and say exactly what you did not review.

### Reviewing AI-written code

It reads confidently and is wrong in specific shapes: invented APIs, flags, or
config keys that don't exist; error handling that catches broadly and silently
swallows; edge cases that look handled but are subtly off (empty input, timezone,
off-by-one at boundaries); tests that assert the implementation back at itself and
would pass with the bug in place; plausible constants nobody chose.

**Never approve a diff you don't understand.** Not "looks reasonable" — understand.
Approval of unread code is the single failure mode with the worst tail, and
generated volume makes it tempting at exactly the wrong moment.

Reviewing your *own* generated code: you have no memory of the tradeoffs because
you didn't make them. Treat it as a stranger's PR — same checklist, no discount.

### Fresh-eyes review during long sessions

When the work and the review would share a context window, dispatch a reviewer
with a crafted brief (what was built, what it should do, the commit range) rather
than the session history — the reviewer stays on the work product, and only the
findings come back. Brief template and its read-only rules:
`references/reviewer-brief.md`.

## Receiving a review

**Separate the signal from the ego hit.** The reflex to defend arrives before the
comment is fully read. Read all of it first; the ranking of what to fix changes
once you see the whole set.

**Ask rather than defend when you disagree.** Either the reviewer knows something
you don't — and the question surfaces it — or they don't, and the question
surfaces that instead, without either of you spending credibility. "What breaks if
we keep it as is?" does more than a paragraph of justification.

**Every comment gets a response**: what changed, or why it didn't. Silent
resolution reads as ignoring. Reply in the comment thread, not as a new top-level
comment where the context is gone.

**Push back on a reason, not a preference.** Legitimate: it breaks a documented
constraint, the reviewer lacks context you can show, the change is unused code
(check before adding — grep for callers), it regresses a supported platform, tests
prove otherwise. Not legitimate: you like yours better. And implementing every
suggestion literally, including the wrong ones, isn't agreeableness — it ships
worse code and teaches the reviewer their wrong calls are correct.

**If any item is unclear, clarify before implementing any of them.** Items are
often related; a partial reading produces the wrong fix twice.

**Skip the performance.** "You're absolutely right", "great catch", thanks-stacking
— the fix in the code is the acknowledgment. If you pushed back and were wrong,
state it in one line and move on; no apology essay.

Reply wording, including reasoned pushback and correcting your own pushback:
`references/comment-templates.md`.

## Gotchas

- **Style comments are a bug report about the repo.** If you're commenting on
  formatting, the project is missing a formatter or lint rule — that's the PR to
  open, and the argument stops being personal the moment a tool owns it.
- **Approval rate rises with diff size, and it shouldn't.** Big diffs get skimmed
  and stamped because reading them costs more than trusting the author. If you
  can't review it all, approve nothing and state your actual coverage: "read the
  handler and the migration; did not review the UI."
- **A problem without a suggestion costs a full round-trip.** "This is fragile"
  makes the author guess which fragility you meant. Name the failing scenario, or
  the shape of the fix, or ask a question instead.
- **"Why didn't you do X?" reads as an accusation even when it's a real question.**
  Add why you're asking: "asking because X would let us drop the retry loop — is
  there a reason it doesn't work here?"
- **The teammate discount is real and asymmetric.** The PR you rubber-stamp for a
  colleague you'd have blocked from a contributor you don't know — and newcomers
  routinely get the harshest review for the smallest diffs. Same bar, both ways.
- **Preferences disguised as standards.** If it's a standard, link it. If you can't
  link it, it's `suggestion:`, and blocking on it is how reviewers acquire a
  reputation that outlives the PR.
- **Approval goes stale the moment you push.** Commits added after an approval are
  unreviewed code with a green check on it — re-request review, and as a reviewer
  check whether the head you approved is still the head being merged.
- **Nobody re-reviews the fix.** The follow-up commit that addresses a blocking
  comment is where new bugs land, precisely because everyone is tired of the PR.
