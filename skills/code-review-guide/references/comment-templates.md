# Comment Templates

Fill the slots. Keep the label prefix — it is the part that unblocks the author.

## Contents
- Writing comments (reviewer)
- Review summary (reviewer)
- Replying to comments (author)

## Writing comments (reviewer)

### blocking:

```
blocking: <what breaks, in one line>

<the scenario that produces it: input, state, or sequence>

<fix, or the shape of one — or "not sure what the right fix is here">
```

Example shape: `blocking: this drops the write when the retry fires. Second call
sees status=pending and returns early, so the record never lands. Either make the
handler idempotent on request_id or move the status flip after the write.`

### suggestion:

```
suggestion (non-blocking): <the change>

<why it's better here — a concrete cost of the current version, not a principle>
```

If you can't name a concrete cost, it's a preference. Send it as a question or drop it.

### question:

```
question: <the actual question>

<why you're asking — what you were expecting, or what you think it would enable>
```

The second line is what stops "why didn't you just use X?" from reading as an
accusation. Never ask a question you already know the answer to as a way of making
a point; say the point.

### nit:

```
nit: <tiny thing>
```

`nit:` means non-blocking, no reply required, merge without it. If you have more
than two, you're reviewing the wrong tier — or the repo needs a linter rule.

### praise:

```
praise: <the specific thing> — <why it matters>
```

Specific and true, or leave it out. `praise: pulling the parser out of the handler
makes this testable without a request fixture` lands. "Nice work!" doesn't.

## Review summary (reviewer)

```
**Verdict:** approve | approve with suggestions | changes requested

**Reviewed:** <files/areas you actually read> — <what you did not review>

**Blocking:**
1. <one line each, linked to the inline comment>
(or: nothing blocking)

**Worth doing, not blocking:** <short list>

**Good here:** <one specific thing>
```

## Replying to comments (author)

Every comment gets one of these. Reply in the thread, not as a new top-level comment.

**Fixed** — say what changed, not that you agree:
```
Fixed in <commit/file:line> — <what changed>.
```

**Disagree, asking first** (default when you think they're wrong):
```
<what I understand you're asking for, restated in one line>.
<the constraint or fact that makes me hesitate>. What breaks if we keep it as is?
```

**Reasoned pushback** (when you have the evidence in hand):
```
Keeping this as is: <reason — constraint, supported platform, existing caller, test>.
<the evidence: file:line, test name, or version requirement>.
Happy to change it if <condition that would make you wrong>.
```

**Not needed / unused** (before implementing "do this properly"):
```
Nothing calls <thing> — grepped <what you searched>. Remove it instead of building
it out, or is there a caller I'm missing?
```

**Unclear** (send before implementing *any* of a multi-item review):
```
Clear on <items>. On <items>: <the specific ambiguity>. Holding off on all of them
until that's settled — they touch the same <code path/decision>.
```

**Can't verify**:
```
Can't verify this without <access/environment/data>. Options: <A> or <B> — which?
```

**You pushed back and were wrong**:
```
You were right — checked <what> and it does <what>. Fixing.
```
One line. No apology paragraph, no defense of why you pushed back.

**Deferring to later**:
```
Filed as <issue/link> rather than doing it here — <why this PR isn't the place>.
```
Only credible with the link. "Follow-up PR" without a filed issue means never.
