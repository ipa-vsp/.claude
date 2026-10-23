# `/rea-wiki-vault --help` — full capability catalog

Shared engineering memory for research and development, testing, debugging,
reverse engineering and visualization. The canonical vault is
`~/rea-wiki-vault` (private `ipa-vsp/rea-wiki-vault`). The commands below are
**natural-language skill routes**, not independent binaries. Replace the
prefix with `$rea-wiki-vault` in Codex; Claude Code and Antigravity use `/`.

## Start and environment

| Command | Behavior | Example |
|---|---|---|
| `--help` or `help` | Display this full guide, NO changes | `/rea-wiki-vault --help` |
| `doctor` | Vault state, tools, permissions, workspace, targets and note gates | `/rea-wiki-vault doctor` |
| `status` | Inventory map/graph freshness and unfinished notes | `/rea-wiki-vault status` |
| `bootstrap` | If vault absent, clone private GitHub repo at ~/rea-wiki-vault | `/rea-wiki-vault bootstrap` |
| `init <id>` | Detect current workspace; preview/register as target, scan and snapshot | `/rea-wiki-vault init my-robot` |
| `map <id>` | Refresh workspace declaration/ROS-endpoint map and pinned environment | `/rea-wiki-vault map fr3-ws` |
| `graph <id>` | Refresh Graphify / link graph / find call paths and hotspots | `/rea-wiki-vault graph fr3-ws` |
| `dashboard <id>` | Build offline Wiki Lab visualization (port 4180) | `/rea-wiki-vault dashboard fr3-ws` |

## Engineering intelligence

| Command | Behavior | Example |
|---|---|---|
| `trace <flow>` | Node/function/topic/controller path; only necessary source is read | `/rea-wiki-vault trace policy to actuator` |
| `search <terms>` | Local indexed wiki BM25 search with filters | `/rea-wiki-vault search Jacobian QP` |
| `query <question>` | Answer from existing notes with provenance and caveats; file reusable analysis | `/rea-wiki-vault query which QP solver is used?` |
| `ingest <pdf/path/url>` | Snapshot source, source note, update synthesized concepts | `/rea-wiki-vault ingest raw/library/paper.pdf` |
| `debug <symptom>` | Hypotheses, reproducer, root-cause evidence and BUG note | `/rea-wiki-vault debug /joint_states jitter` |
| `test <scenario>` | Exact static/unit/launch/sim/fault/hardware gate results | `/rea-wiki-vault test singularity regression` |
| `experiment <run>` | RL/IL/VLA RUN note, seeds, metrics, config/version and baselines | `/rea-wiki-vault experiment PPO vs BC` |
| `adr <decision>` | Options, rationale, risks, validation, rollback, ADR note | `/rea-wiki-vault adr weighted vs hierarchical QP` |
| `runbook <procedure>` | Reproducible installation/operation guide and safety gates | `/rea-wiki-vault runbook vcan testing` |
| `lint` | `check_notes.py` + `lint_wiki.py`, source drift, orphans, debt | `/rea-wiki-vault lint` |
| `rea <opaque artifact>` | Analyze binary, firmware, vendor plugin, web/Electron, pcap, traces | `/rea-wiki-vault rea libvendor_hw.so` |

## Components the skill unifies

- **Agent + rules:** `CLAUDE.md` is canonical, `AGENTS.md` for Codex/others,
  `templates/prompts.md` provides reusable requests.
- **Graphify skill + CLI:** source AST/dependency graph, god-nodes, path,
  `affected`, `explain`, `query`, `update`, watch; graph file linked under
  `generated/graphify/<id>`, shown in the browser and Obsidian.
- **REA MCP:** permitted opaque binary/ELF/firmware, Frida/gdb, browser captures,
  packet/candump/pcap; optional tools such as Ghidra/tshark must exist.
- **Obsidian:** dashboard, knowledge graph/backlinks, Dataview, concepts, hubs,
  `[[wikilinks]]` and note templates.
- **Scanner:** `tools/scan_ros_ws.py` -> declaration, endpoints, repos, triage,
  ROS nodes/topics, functions, file hashes, plugins; does not prove runtime.
- **Environment:** `tools/env_snapshot.py` -> OS/ROS distro/RMW/GPU/CAN/
  EtherCAT/commits, target compatibility matrix.
- **Quality:** `tools/check_notes.py` -> note schema, link checks, vocabularies;
  `tools/lint_wiki.py` -> stale, contradictions, orphans, un-ingested sources.
- **Search and visualization:** `tools/search_wiki.py` (BM25),
  `tools/build_dashboard.py` + `dashboard/` (interactive radial map), Obsidian
  Graph View and Dataview.
- **Evidence:** `raw/<id>/` immutable snapshots, captures, traces and env JSON;
  `raw/library/` papers, webpages, manuals, specs; source notes cite hashes.
- **Audit:** `index.md` catalog, `log.md` append-only, source pinning and SEEN/
  INFERRED/UNKNOWN/doc-cited labels.
- **Domains:** ROS 2 any distro; ros2_control, whole-body and Cartesian control,
  QP/IK, planning, CANopen, EtherCAT, RL/IL/VLA (including camera-free state
  policies), sim (MuJoCo/IsaacLab), Docker and safe deployment.

## All 14 note templates

| Input | Template | Output |
|---|---|---|
| Paper, website, manual, specification | `source.md` | `wiki/sources/` |
| Algorithm, concept, mathematical derivation | `concept.md` | `wiki/concepts/` |
| Compare technologies or research claims | `analysis.md` | `wiki/analyses/` |
| ROS 2 node or controller | `node.md` | `wiki/nodes/` |
| Callback/function/method | `function.md` | `wiki/functions/` |
| ROS topic/service/action/parameter | `interface.md` | `wiki/interfaces/` |
| End-to-end sensor/policy/controller flow | `feature.md` | `wiki/features/` |
| Failure/crash/incorrect behavior | `bug.md` | `wiki/debug/` |
| Executed test cycle | `test-session.md` | `wiki/debug/` |
| RL/IL/VLA training or evaluation | `experiment.md` | `wiki/experiments/` |
| CANopen node/EtherCAT slave | `device.md` | `wiki/devices/` |
| PDO/SDO/NMT/CoE/SYNC/EMCY mapping | `fieldbus-interface.md` | `wiki/interfaces/` |
| Architecture/design choice | `adr.md` | `wiki/decisions/` |
| Repeatable setup/operational procedure | `runbook.md` | `wiki/runbooks/` |

## Example prompts

**Project onboarding:** `/rea-wiki-vault init fullbody-ws` — inspect current
workspace; register target, create graph, map functions, compatibility snapshot,
dashboard; don't edit robot code.

**Paper:** `/rea-wiki-vault ingest https://arxiv.org/abs/...` — preserve PDF or
article in raw/library; create source note with pages; link and update concepts;
mark knowledge gaps for PhD novelty assessment.

**Controller:** `/rea-wiki-vault trace whole-body Cartesian command through QP
solver to ros2_control` — Graphify lead, verify each source hop, note constraints,
check singularity behavior with offline tests.

**CANopen:** `/rea-wiki-vault debug missing CiA402 PDO on vcan0` — record
EDS/DCF, trace config to interfaces, read-only traffic or vcan, TEST + BUG notes.

**RL:** `/rea-wiki-vault experiment camera-free BC to PPO recovery policy` —
environment contract, consistent seeds, baseline, metrics, checkpoint hash,
constraint/safety checks and RUN note.

**Knowledge management:** `/rea-wiki-vault query Compare the papers on
hierarchical QP vs whole-body motion optimization and list open gaps.`

## Permissions and setup

- **Install skill once globally**; it is discoverable in any workspace, including
  one where the vault does not exist yet. See package README.
- **Claude:** start `claude --add-dir ~/rea-wiki-vault` from target workspace.
- **Codex:** `codex --sandbox workspace-write --add-dir ~/rea-wiki-vault`
  when supported; inspect `codex --help` and current permissions.
- **Antigravity CLI:** in session `/add-dir ~/rea-wiki-vault`; use `/permissions`.
- **Do not** bypass permission gates. User approval is required for live hardware
  writes and large/destructive actions.

## Native helper command (optional)

`rea-wiki-vault help`, `rea-wiki-vault doctor`,
`rea-wiki-vault bootstrap --apply`,
`rea-wiki-vault setup --workspace "$PWD" --target <id> --apply`,
`rea-wiki-vault dashboard --target <id> [--serve]`.
The Python helper automates setup/checks; agent routes handle research and synthesis.
