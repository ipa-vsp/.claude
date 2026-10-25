# Fresh-Eyes Reviewer Brief

For dispatching a reviewer (subagent or human) on work you just did, when the
implementation context would otherwise contaminate the review.

**Why a crafted brief and not the session history:** the history contains your
reasoning, which is exactly what the reviewer must not inherit — they'd validate
your thinking instead of the code. It also costs the coordinating context far more
than the findings that come back.

## Brief template

```
Review the change in <BASE_SHA>..<HEAD_SHA>.

WHAT IT'S MEANT TO DO
<one paragraph: the problem, not the implementation>

REQUIREMENTS / PLAN
<the spec, task text, or plan file path it should satisfy>

WHAT I'M UNSURE ABOUT
<the two or three places you'd most like a second opinion — omit if none>

HOW TO REVIEW
- Start with intent: does the diff solve the stated problem, or an adjacent one?
- Then rank findings by consequence: correctness/security > hard-to-reverse design
  > tests of the risky paths > clarity. Do not comment on formatting.
- Label every finding blocking / suggestion / question. Not everything is blocking.
- Cite file:line, say what's wrong, why it matters, and the shape of the fix.
- Flag deviations from the plan explicitly so I can confirm whether they were
  intentional; if the plan itself is wrong, say that instead.
- If you didn't read part of it, say which part.

READ-ONLY
Do not modify the working tree, index, HEAD, or any branch. Inspect with
`git diff <BASE_SHA>..<HEAD_SHA>`, `git show`, `git log`. If you need another
revision checked out, use a separate worktree — never move HEAD here.

RETURN
Verdict (approve | approve with suggestions | changes requested), what you
reviewed and what you skipped, numbered blocking list, non-blocking list, and one
specific thing that's genuinely good.
```

## Using it

- Commit range: `git rev-parse origin/main` for base and `git rev-parse HEAD` for
  head, or the two task commits if you're reviewing one step of a plan.
- Review per meaningful unit of work, not once at the end — findings that arrive
  after three more features have been built on top are the expensive kind.
- Act on the return: blocking items before anything else, non-blocking ones tracked
  or explicitly dropped. Read the diff of the fixes yourself; a reviewer's or an
  agent's "all fixed" is a claim, not evidence.
- The reviewer can be wrong. Push back with the reason, same rules as any review.
