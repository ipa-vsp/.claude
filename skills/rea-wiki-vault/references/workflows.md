# Operational recipes — refer to the current vault `Usage.md` and `CLAUDE.md`

## Before touching workspace or vault

1. Identify the host agent (Claude/Codex/agy), its cwd and permitted roots.
2. Resolve `$REA_WIKI_VAULT` if set, else `~/rea-wiki-vault`. The fixed repository is private.
3. If missing, `scripts/vault.py bootstrap` previews the clone; execute
   `bootstrap --apply` only under requested bootstrap/onboarding. Never overwrite
   existing unrelated dirs and never auto-pull or force-reset.
4. If the current workspace is not registered, preview `setup --workspace "$PWD"
   --target <unique-slug>`; guide the user to grant vault write permission, then
   initialize. Check `targets/<slug>.md`, `raw/<slug>`, `dashboard/data/<slug>.js`.
5. Read the vault canonical `CLAUDE.md` and `AGENTS.md`, `index.md`, hubs and
   target notes. Ensure permissions and directory access before editing.

## Research paper / website ingestion

1. Get complete source by local file, accessible URL or approved Web Clipper.
   If web fetch requires credentials or is prohibited, ask for permitted copy.
2. Preserve source immutably in `raw/library/` or `raw/<target>/docs/` with
   filename, checksum, retrieval date and URL. Never save secrets.
3. Read the relevant `templates/source.md`; write 3-5 takeaways first if task
   unclear. Cite page/section or HTML anchor, not just document title.
4. Search `wiki/concepts/` before creating concepts. Revise existing synthesis:
   which propositions follow from which sources? How do they compare to code?
5. Cross-link relevant hubs, targets, function/feature notes; record
   contradictions, assumptions and unanswered questions, avoiding fake claims.
6. Update `index.md`, `log.md`, note gate and wiki lint.

## ROS source investigation or development

- Before expensive reads, scan or check freshness of `workspace-map.json` and
  Graphify; note ROS distro/OS/RMW/ABI/container and source HEAD. Do not assume
  one ROS 2 distro.
- Pick one trace (e.g. Planner -> trajectory interface -> ros2_control plugin).
  Use Graphify `path`/`affected`, then independently inspect relevant source
  files with `repo@commit:path:line`. Generate `node.md`, `function.md`,
  `interface.md`, `feature.md` note(s). Link tags and exact `source: path:line`
  so dashboard recognizes documented functions.
- When building a feature: first describe integration, risks, criteria, minimal
  diff, test ladder and rollback. Ask permission before source edit.

## Debug / TEST workflow

1. Capture symptoms, expected vs actual, environment, reproducible command
   and objective acceptance criteria. Create `bug.md` as investigating.
2. Rank competing hypotheses and select one discriminating test per hypothesis.
3. Run static/unit/launch/sim-vcan/fault-injection/hardware-approved stages
   in that order. Explicitly report N/M pass or not run.
4. Distinguish hypotheses from verified root causes. Link TEST and BUG notes,
   affected function/interface notes, and ADR when changing system contracts.
5. Keep simulator and hardware environments separate and protect safety gates.

## RL, imitation learning, and VLA

- Verify reset/step/reward/termination/truncation, observations/actions, units,
  shape, normalization, NaN/Inf and safety bounds before expensive training.
- Baseline first: deterministic, scripted, or BC. Fixed held-out evaluation
  scenarios, repeat seeds, cite env/dataset/commit/checkpoint hash.
- Compare success/collisions/constraint violations/timing with confidence and
  uncertainty. Only state actual executed evaluation results.
- Camera-free proprioceptive policy is state-conditioned, not automatically VLA.
- Save `experiment.md` in `wiki/experiments/RUN-YYYY-MM-DD-*`.

## CANopen / EtherCAT

- Collect EDS/DCF/ESI, configs, node/slave identity, PDO/SDO mapping,
  CiA 402 state machine, heartbeat and bus captures as **passive evidence**.
- Link `device.md`, `fieldbus-interface.md`, relevant `ros2_control` plugin
  and captures. Use `vcan` or offline files for output frames.
- Do NOT transmit NMT/SDO/PDO/controlword or EtherCAT control to live buses
  or run `sudo` network config without explicit targeted approval.

## REA reverse engineering

- Appropriate: opaque library/firmware, shipped HMI/compiled extension,
  gdb/Frida trace, authorized network capture. Skip if source exists.
- Choose actual installed provider capability, run doctor, inspect only
  symbols + relevant behavior (not entire binary). Saved REA evidence IDs,
  addresses and timestamps are cited in the notes.
- Optional REA doctor: `npx -y rea-agents@6.7.0 doctor --client claude_code --json`.
  Do not silently download/deploy REA, Ghidra, tshark or other engines.

## Questions and weekly maintenance

- Query: `python3 -I tools/search_wiki.py . "term" --domain ros2` then cite
  verified notes, flag unknowns; save reusable answer in `analysis.md`.
- `tools/check_notes.py` is a note schema/link gate. `lint_wiki.py` diagnoses
  orphans, stale source paths, contradictions and un-ingested source items.
- `tools/build_dashboard.py . <target>` feeds `dashboard/index.html?t=<id>`.
- Append relevant activity to `log.md`, never erase audit history.
