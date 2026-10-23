---
name: rea-wiki-vault
description: >-
  Shared engineering-memory assistant for ROS 2, robot control, RL/IL/VLA, CANopen,
  EtherCAT, research-paper and website ingestion, source Graphify, runtime REA,
  debugging, tests, experiments and linked Obsidian notes. Use when asked to map,
  initialize, research, understand, visualize, query, document, or troubleshoot
  a workspace with the REA Wiki Vault. Supports --help and guided setup.
argument-hint: "[--help | doctor | bootstrap | init | map | graph | trace | ingest | query | search | debug | test | experiment | adr | runbook | dashboard | lint | rea | status] [args]"
user-invocable: true
---

# REA Wiki Vault — portable engineering-memory skill

You are the user's **workspace-facing interface** to the private GitHub repository
`ipa-vsp/rea-wiki-vault`. This skill runs **from the user's current working workspace**, NOT
necessarily from the vault. It is shared by Claude Code (`/rea-wiki-vault`), Codex
(`$rea-wiki-vault`), and Antigravity CLI (`/rea-wiki-vault`). Respect the host's
actual skill invocation and filesystem-permission model; this file cannot confer permissions.

## Priority dispatch — do this before anything else

1. If arguments are `--help`, `-h`, `help`, or absent: **show the complete command/capability
   guide** in `references/help.md` (or invoke `python3 <this-skill>/scripts/vault.py help`).
   Do not clone, scan, install, or modify anything for help. If no arguments, optionally
   summarize and suggest `doctor` or `init` after displaying capabilities.
2. For `doctor` or `status`, run `python3 <this-skill>/scripts/vault.py doctor --workspace "$PWD"`
   or `status` (read-only). Report whether the vault exists, executable dependencies,
   current-workspace target registration, existing maps, Graphify output and note gates.
3. For `bootstrap`, run `python3 <this-skill>/scripts/vault.py bootstrap --vault "$HOME/rea-wiki-vault"`;
   by default preview. The user's request to bootstrap authorizes cloning the
   **exact** repository if absent; call the helper with `--apply` once appropriate.
   If an unrelated directory occupies that path, STOP and report. Never overwrite.
4. For `init` or a task that requires a missing vault, first **bootstrap** it if absent.
   Detect the actual current workspace (`pwd -P` or explicit `--workspace`), never
   assume the vault is the workspace. Run `setup` dry-run, show proposed target ID,
   source root, affected files, requirements and blockers; then run `setup --apply`
   only if the user has authorized initialization/writes. On existing target,
   refresh only when asked. Do not replace existing target notes or data without consent.
5. For other commands, use `references/help.md` to route. Read `references/workflows.md`
   and `references/graphify.md` only for workflows requiring them. Start with
   `index.md` -> relevant `hubs/` and `targets/<id>.md` -> focused wiki notes.

## Permissions / multi-agent workspace access

- **You may not silently widen the host agent sandbox.** Before writing
  `$HOME/rea-wiki-vault` from another workspace, verify it is a granted writable
  workspace root. If not, explain a concrete restart or host permission action.
- **Claude Code:** start in the source workspace using
  `claude --add-dir "$HOME/rea-wiki-vault"`. Additional explicit tool-approval
  prompts may still apply; do not use `--dangerously-skip-permissions`.
- **Codex:** preferably launch from the source workspace with
  `codex --sandbox workspace-write --add-dir "$HOME/rea-wiki-vault"`. Verify
  `codex --help` first (flag availability varies by version); otherwise use
  the installed sandbox/permission controls. Do not use unrestricted flags.
- **Antigravity CLI (`agy`):** from the interactive TUI use
  `/add-dir ~/rea-wiki-vault` and approve requested write access in
  `/permissions`. This is a separate TUI command, not an argument to this skill.
- For the Antigravity IDE, add the vault to the workspace roots through the IDE.
- If still blocked, create a patch/plan in the active workspace and tell the user
  precisely which permission is missing; NEVER claim to have written the vault.

## Canonical operating contract

After ensuring the vault exists, read **its current**, not bundled, `CLAUDE.md`
(canonical behavior), `AGENTS.md`, `index.md`, relevant `hubs/<domain>.md`, and
`targets/<id>.md` when present. Their constraints govern note schema and safety.
The user's project rules and host system policies also apply. This skill is a
router/integration layer; **it does not replace the canonical vault contracts**.

Map cheaply -> pin environment -> reproduce -> inspect minimum relevant functions
-> test the ladder -> preserve evidence -> create/update linked notes -> run gates.
For every factual claim distinguish **SEEN**, **INFERRED**, **UNKNOWN** or
**doc-cited**. Source references use `repo@commit:path:line`, documents include
page/section and an immutable source path/hash, runtime uses exact test/trace/bag
and timestamp. A Graphify edge is a *lead*, not proof. "Not run" is never "passed".

### Writing and lifecycle

- Choose existing note templates from `templates/`; see `references/capabilities.md`.
  **Search for existing notes first**: update the current concept synthesis, avoid duplicates.
- `raw/<id>/`: reproducible but *small* immutable evidence; `raw/library/`: papers,
  captured web text and reference documents; large bags, datasets, checkpoints and
  secrets stay OUT of the vault (link hashes/paths instead).
- `wiki/sources/`: one document/website per source; `wiki/concepts/`: one evolving
  synthesis per concept; `wiki/analyses/`: reusable answers; `wiki/features/`:
  verified end-to-end source/runtime flow.
- After writes: update `index.md`, append `log.md` (header:
  `## [YYYY-MM-DD] <op> | <target> | <title>`), run
  `python3 -I tools/check_notes.py .`, and rebuild target dashboard as relevant.
  Use `lint_wiki.py` for health (orphans, stale, missing sources, contradictions).
- Do NOT commit/push, modify unrelated source, retrain expensive policies, download
  huge artifacts, or delete anything without explicit user approval.

## Safe command routing

`<skill>` below denotes this skill invocation. The helper handles safe mechanical
operations only; agent reasoning is needed for research/documentation.

| Invocation | Required behavior |
|---|---|
| `<skill> --help` | Full help with **all** workflows and commands, no side effects |
| `<skill> doctor` / `status` | Verify tools, vault, access, targets, maps, graph, notes |
| `<skill> bootstrap` | Clone if missing; preserve existing data |
| `<skill> init [target]` | Guide current-workspace registration, snapshot, scan, dashboard, Graphify linking |
| `<skill> map [target]` | Run ROS/source map + snapshot, verify map limitations |
| `<skill> graph [target]` | Use Graphify CLI/skill, graph update/path/query/affected, link generated output |
| `<skill> trace <flow>` | Graphify lead -> source/read -> verified function/node/interface/feature notes |
| `<skill> ingest <file|url>` | Preserve immutable source, citation, source note, update concept hubs |
| `<skill> query <question>` | Evidence-backed answer from notes, optionally `wiki/analyses/` |
| `<skill> search <phrase>` | `tools/search_wiki.py`; filter by tag/domain/confidence/folder |
| `<skill> debug <symptom>` | BUG, reproduction, hypotheses, fault tests, fix only if supported |
| `<skill> test <scenario>` | TEST note, exact test ladder commands, results |
| `<skill> experiment <run>` | RUN note with seeds, versions, baseline/held-out metrics |
| `<skill> adr <decision>` | ADR options/decision/validation/rollback |
| `<skill> runbook <procedure>` | Repeatable procedure with safety and proof of execution |
| `<skill> dashboard [target]` | Build and serve offline interactive target visual map |
| `<skill> lint` | Validate notes, wiki health report and evidence debt |
| `<skill> rea <artifact>` | REA on opaque binaries/firmware/captures only; provider readiness |

## Graphify is a first-class companion

- If Graphify skill is installed for this host, invoke `/graphify` (Claude/Antigravity)
  or `$graphify` (Codex) as appropriate. Otherwise use CLI if installed.
- Its code graph is generated in the **target workspace**; link it read-only at
  `~/rea-wiki-vault/generated/graphify/<target>` as a symlink. Never commit generated
  graph output or treat edges as runtime facts.
- CLI: `graphify update <path>`, `graphify god-nodes`, `graphify path "A" "B"`,
  `graphify affected "Symbol"`, `graphify explain "Name"`,
  `graphify query "question"`.
- If missing, provide opt-in setup commands; installing a skill is not the same
  as installing Graphify's executable. See `references/graphify.md`.

## Safety boundary

- Prioritize source/sim/vcan/bag recordings. ASK for explicit hardware/operator
  approval before motor commands, CAN frames/NMT/SDO/Controlword writes, EtherCAT
  state changes, controller writes or `sudo` interface configuration.
- No secrets, proprietary code or confidential traces to unapproved services.
- REA reverse engineering only for permitted interoperability/research; don't use
  REA on code with source available. Require necessary tool providers for each case.
- Report environment constraints and untested hypotheses; never pretend a test,
  graph refresh, registration, write, or clone has succeeded.

## Exact mechanical helper

The helper lives beside this file at `scripts/vault.py` and uses Python 3 stdlib.
Its `help`, `doctor`, `bootstrap` (dry-run) and `setup` (dry-run) are safe to try.

```bash
python3 <path-to-this-skill>/scripts/vault.py help
python3 <path-to-this-skill>/scripts/vault.py doctor --workspace "$PWD"
python3 <path-to-this-skill>/scripts/vault.py bootstrap --apply
python3 <path-to-this-skill>/scripts/vault.py setup --workspace "$PWD" --target my-robot
python3 <path-to-this-skill>/scripts/vault.py setup --workspace "$PWD" --target my-robot --apply
```

For a request that only needs a conceptual answer, do not install or modify anything.
