---
name: harness2-setup
description: "Install and set up Harness² (the Claude-compatible harness2-cli fork of google-research/harness2) in a project for Claude Code, Codex or agy (Antigravity CLI): uv install pinned to Python 3.12, `harness2 init` per agent, quota guardrails, first task, doctor and dry-run. Use when the user asks to install, set up, configure or check harness2 / Harness², or to start tuning a project's CLAUDE.md / AGENTS.md / skills with it. Never starts a real run or apply."
---

# harness2-setup

Sets up Harness² so it can tune a project's harness: CLAUDE.md or AGENTS.md, skills, subagents, scripts and hooks. Full usage and background: `wiki/runbooks/Harness2 setup and usage.md` in the REA wiki vault.

Everything goes through `scripts/setup_harness2.sh` (next to this file), which runs the same way from Claude, Codex or agy:

```bash
H2=.claude/skills/harness2-setup/scripts/setup_harness2.sh   # from the vault root; else use the absolute path
$H2 check   [--dir D]                       # tools, logins, git state, .harness2 present? (read-only)
$H2 install [--upgrade] [--ref COMMIT]      # uv tool install --python 3.12 git+https://github.com/ipa-vsp/harness2
$H2 init <claude|codex|agy> [--dir D] [--model provider/model] [--improver provider/model]
         [--max-calls N] [--force]
$H2 doctor  [--dir D]                       # harness2 doctor (no model calls)
```

## Procedure

1. **Ask** which project directory and which agent (`claude` | `codex` | `agy`) if the request doesn't say. Never guess a project.
2. **Preflight:** `$H2 check --dir <project>`. Stop and report if the project is not a git repo: runs use git worktrees and only see **committed** files. Tell the user to commit harness files before a run.
3. **Install** if `harness2` is missing: `$H2 install`. It is idempotent; `--upgrade` reinstalls. Report the pinned commit it prints.
4. **Init:** `$H2 init <agent> --dir <project>`.
   - The script refuses if `.harness2/config.toml` exists. Show the user the existing file and use `--force` only with their OK.
   - Defaults: Claude `claude-login/claude-sonnet-5-5` runs tasks and `claude-login/claude-opus-5-5` improves; Codex `chatgpt-login/gpt-6.1-sol`; Antigravity `antigravity-login/gemini-3-flash-preview` runs tasks and `antigravity-login/gemini-3.1-pro-high` improves. Override with `--model` / `--improver`.
   - **codex:** the user must run `! harness2 login codex` once. It opens a browser, so never run it yourself. Use `--device` on headless machines.
   - **agy (`antigravity`):** native `AntigravitySubstrate` (`--executor antigravity --auth login`) tunes `AGENTS.md`, `.agents/skills`, `.agents/agents` (with `subagent: true`), `.agents/scripts`, and `.agents/hooks.json`.
   - Guardrails written for every agent: `run.max_calls=50`, `run.phase_width=1`, `run.proposer_concurrency=1`.
5. **First task:** `harness2 -C <project> task new <id> [--check "<cmd>"] [--domain D]`, then write `.harness2/tasks/<id>/task.md` as the request a person would really make (a request, not a test). Hidden grader files go in `check/`, LLM-judge criteria in `rubric.md` (one checkable line each). For ROS 2 workspaces, a typical check runs from the workspace root: `colcon build --packages-select <pkg> && colcon test --packages-select <pkg> && colcon test-result --verbose`. Tasks must never drive real hardware or a live fieldbus.
6. **Verify:** `$H2 doctor --dir <project>` (all rows ok), then `harness2 -C <project> run --dry-run`. Report the task list and model-call count.
7. **Stop there.** `harness2 run`, `eval` and `apply` spend subscription quota or write project files. Give the user the next commands (`run --max-calls N`, `status --watch`, `diff`, `apply -i --branch harness2/<name>`) and run them only after an explicit go-ahead.
8. Optional, with consent (writes outside the project): `harness2 guide --install claude` installs the upstream operator skill at `~/.claude/skills/harness2/`.

## In the REA wiki vault
Append each setup or run to `log.md` (command · evidence · output · result) and update "Last run here" in the runbook. Never commit.
