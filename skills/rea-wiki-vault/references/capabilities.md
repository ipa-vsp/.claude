# Repository architecture quick reference

Trust live `README.md`, `Usage.md`, `CLAUDE.md`, `AGENTS.md` over this summary.

| Element | Purpose |
|---|---|
| `00-Dashboard.md` | Obsidian home and Dataview tables |
| `CLAUDE.md`, `AGENTS.md` | Canonical evidence, safety, test and note schema |
| `hubs/` | ROS2, Robot-Control, RL, VLA, CANopen, EtherCAT topic maps |
| `targets/<id>.md` | Per-workspace map, compatibility matrix and Graphify freshness |
| `templates/` | 14 note templates and `prompts.md` agent recipes |
| `wiki/functions/` | one callback/method or UI trigger note |
| `wiki/nodes/` | one ROS node/component/plugin note |
| `wiki/interfaces/` | topic/action/service/parameter or fieldbus entry |
| `wiki/devices/` | CANopen/EtherCAT device |
| `wiki/features/` | connected end-to-end execution flows |
| `wiki/debug/` | BUG and TEST notes |
| `wiki/experiments/` | RUN notes for RL/IL/VLA |
| `wiki/decisions/` | ADR records |
| `wiki/runbooks/` | reproducible commands with preconditions |
| `wiki/sources/` | single paper, website, standard, datasheet |
| `wiki/concepts/` | updated synthesis across sources/targets |
| `wiki/analyses/` | evidence-backed queries and comparisons |
| `raw/library/` | immutable documents and captures not tied to a target |
| `raw/<id>/` | immutable workspace maps, captures, environment details |
| `generated/graphify/<id>/` | symlink to external Graphify outputs |
| `dashboard/` | offline interactive radial function/test graph |
| `index.md`, `log.md` | indexed note catalog and append-only audit |

## Python tools supplied by the vault

```
python3 -I tools/scan_ros_ws.py <workspace> raw/<id>/workspace-map.json \
  [--src SRC] [--first-party-host HOST]
python3 -I tools/env_snapshot.py . <id> --ws <workspace>
python3 -I tools/build_dashboard.py . <id> [--title TITLE]
python3 -I tools/check_notes.py .
python3 -I tools/lint_wiki.py . [--json]
python3 -I tools/search_wiki.py . "search phrase" [--domain D] [--tag T]
python3 -m http.server 4180 --bind 127.0.0.1 --directory dashboard
```

The scanner reads declarations, not function bodies; its heuristic scan may
miss macros, generated code and computed topic names. Environment snapshots
are point-in-time, not a proof of runtime compatibility.

## Note-template choice

- `source.md`: one source; `concept.md`: synthesis of many sources;
  `analysis.md`: one answer/comparison.
- `node.md` + `function.md` + `interface.md` -> `feature.md`: source trace.
- `bug.md` -> `test-session.md`: failure/repro/fix/regression.
- `experiment.md`: seeded training/evaluation and metrics.
- `device.md` + `fieldbus-interface.md`: motor drive or slave and PDOs.
- `adr.md`: decision; `runbook.md`: repeatable safe procedure.
