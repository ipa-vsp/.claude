# Graphify integration and agent skill installation

Graphify is a source/doc **graph**, not runtime proof. The Graphify CLI is from
`graphifyy`; install the executable and then its per-agent skill(s) separately.

```bash
uv tool install graphifyy
# Graphify registers a skill for each platform independently:
graphify claude install
graphify codex install
graphify antigravity install
# equivalent: graphify install --platform claude | codex | antigravity
```

Use platform skill names `/graphify` for Claude/Antigravity, `$graphify`
for Codex. Agent-local discovery still requires the correct workspace or
user skills path; restart session when necessary. Before using any generated
flow, verify the timestamp is at least as current as the source commit.

**Graph commands** (shell, with actual workspace path):

```bash
graphify update <workspace-or-source>
graphify god-nodes
graphify explain "MujocoSystemInterface"
graphify affected "Controller::update"
graphify path "PolicyNode" "write"
graphify query "where is CAN heartbeat timeout configured?"
# optional commands if supported by installed version:
graphify watch <workspace-or-source>
graphify merge-graphs <a>/graph.json <b>/graph.json --out merged.json
```

Expected Graphify output is typically `<workspace>/graphify-out/`. Inspect
actual output before linking it:

```bash
mkdir -p ~/rea-wiki-vault/generated/graphify
ln -s ~/ros_ws/fullbody/colcon_rox_fr3_ws/graphify-out \
      ~/rea-wiki-vault/generated/graphify/fr3-ws
```

If a link/directory already exists, do not overwrite it without examining
its destination. `generated/` is machine-local/gitignored. `GRAPH_REPORT.md`
is for Obsidian; `graph.html` opens in browser; the `graph.json` should not
be expanded into per-node Obsidian notes. Document only a selected flow.

**Fallback if unavailable:** `tools/scan_ros_ws.py` maps declarations and ROS
endpoints with Python stdlib, so vault onboarding still works without Graphify.
Source reasoning can proceed without a graph; mark cross-file relationships
not proven by inspected source as INFERRED.

Before describing all platform support, prefer current Graphify docs:
https://graphiffy.com/docs/install
