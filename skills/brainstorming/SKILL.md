---
name: brainstorming
description: >-
  Turns a rough idea into an agreed design before anything gets built. Use when the
  user wants to create a feature, product, campaign, or system and requirements are
  still fuzzy — ask focused questions, propose approaches, get sign-off on a spec.
license: MIT
metadata:
  brand: How to AI by Ruben Hassid
  protocol: howtoai-v1
  source: obra/superpowers
  source-sha: 44c9b2d
  source-license: MIT
  upgraded: "2026-08"
  claude-ai-description: >-
    Turn a rough idea into an agreed design before building. Explores context, asks
    focused questions one at a time, proposes approaches, and gets sign-off on a spec.
---

# Brainstorming

Turn "I want to build X" into a design both of you actually agree on — before any
building starts. The cost of a design conversation is minutes; the cost of building
the wrong thing is the whole build.

This applies to anything that gets built or shipped: software, a landing page, a
content system, a campaign, an automation. "Too simple to need a design" is the
classic trap — small projects are where unexamined assumptions waste the most work.
For a genuinely tiny task the design can be two sentences, but it still gets shown
before work starts.

## The loop

1. **Explore first.** Look at what already exists — files, docs, past work, the
   current state of whatever this touches. Never open with questions the context
   already answers.
2. **Check the size.** If the idea contains several independent pieces ("a platform
   with chat, billing, and analytics"), say so now and help decompose it. Design the
   first piece; don't refine details of something that needs splitting.
3. **Ask questions — one per message.** Purpose, constraints, success criteria.
   Multiple-choice beats open-ended when the options are real. People answer one
   sharp question well and three stacked questions badly.
4. **Propose 2–3 approaches**, lead with your recommendation and why. Apply YAGNI
   ruthlessly — strip every feature the goal doesn't need.
5. **Present the design in sections** scaled to their complexity — a few sentences
   where it's obvious, a paragraph where it's nuanced. Confirm each section lands
   before moving on. Cover structure, components, flow, failure cases, and how
   you'll know it works.
6. **Write the spec and get sign-off.** Save it where the project keeps docs (ask
   if unclear), self-review it (below), then have the user read it before any
   building starts. The step after an approved spec is a plan — if the `plan-first`
   skill is available, use it.

## Design quality bar

- Break the system into units with one clear purpose each and well-defined
  interfaces. Test: can someone tell what a unit does without reading its internals?
  Can internals change without breaking consumers? If not, redraw the boundaries.
- In existing projects, follow the established patterns. Fold in targeted
  improvements only where existing problems directly affect this work — no
  drive-by refactors.

## Spec self-review

Before showing the spec, re-read it fresh and fix inline:

- Placeholders — any "TBD", vague requirement, or empty section.
- Contradictions — sections that disagree with each other.
- Ambiguity — any requirement readable two ways gets pinned to one.
- Scope — still one buildable piece, or did it grow?

## Gotchas

- Users usually describe a solution, not their problem. Before refining their
  solution, find the problem — the best design is often not the one they arrived with.
- The urge to skip design is strongest exactly when it's cheapest: "it's a quick
  one" precedes most wasted builds. Show the two-sentence design anyway.
- Don't interrogate. If context answers a question, don't ask it; if the user has
  clearly decided something, don't relitigate it.
- An approved design is a contract, not a cage — if building reveals the design was
  wrong, stop and renegotiate rather than silently diverging.
