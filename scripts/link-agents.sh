#!/usr/bin/env bash
# link-agents.sh — expose this .claude/ config to other coding agents via symlinks.
#
# Nothing is copied: every entry created is a relative symlink back into
# .claude/, so editing a skill/rule/agent here updates every agent at once.
# Links are created in the current directory, or in <path> when -l <path> is
# given. With -l, a .claude symlink is also created in <path> and the agent
# links go through it (e.g. <path>/.agents/skills -> ../.claude/skills).
#
# Usage:
#   .claude/scripts/link-agents.sh <agent> [<agent> ...]   create links in $PWD
#   .claude/scripts/link-agents.sh -l <path> <agent> ...   create links (+ .claude) in <path>
#   .claude/scripts/link-agents.sh --remove <agent> ...    remove links (combine with -l)
#   .claude/scripts/link-agents.sh --list                  show supported agents
#   .claude/scripts/link-agents.sh all                     every supported agent
#
# Example:
#   .claude/scripts/link-agents.sh codex agy
#   .claude/scripts/link-agents.sh -l ~/other_ws codex

set -euo pipefail

CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT=""        # destination directory, set in main()
VIA_LOCAL=0    # 1 = link targets go through $ROOT/.claude

# Each mapping is "<link path relative to ROOT>:<target path relative to .claude/>".
# Only formats the agent reads natively are linked — e.g. Codex subagents are
# TOML and Gemini commands are TOML, so .claude/agents and .claude/commands
# (Markdown) are not linked for them.
declare -A MAPPINGS=(
  [codex]="AGENTS.md:CLAUDE.md .agents/skills:skills .codex/skills:skills"
  [agy]="AGENTS.md:CLAUDE.md .agents/skills:skills .agents/rules:rules .agents/workflows:commands"
  [gemini]="GEMINI.md:CLAUDE.md .gemini/skills:skills .gemini/agents:agents"
  [cursor]="AGENTS.md:CLAUDE.md .cursor/skills:skills .cursor/agents:agents .cursor/commands:commands"
  [copilot]=".github/copilot-instructions.md:CLAUDE.md .github/skills:skills"
  [opencode]="AGENTS.md:CLAUDE.md .opencode/skills:skills .opencode/commands:commands"
  [windsurf]="AGENTS.md:CLAUDE.md .windsurf/skills:skills .windsurf/rules:rules .windsurf/workflows:commands"
  [kiro]=".kiro/skills:skills .kiro/steering:rules"
  [cline]="AGENTS.md:CLAUDE.md .agents/skills:skills .clinerules:rules"
  [amp]="AGENTS.md:CLAUDE.md .agents/skills:skills"
  [roo]="AGENTS.md:CLAUDE.md .roo/skills:skills .roo/rules:rules"
  [goose]="AGENTS.md:CLAUDE.md .goose/skills:skills"
)
declare -A ALIASES=(
  [antigravity]=agy [openai]=codex [gemini-cli]=gemini [github]=copilot
  [vscode]=copilot [kiro-cli]=kiro [roo-code]=roo
)
declare -A DESCRIPTIONS=(
  [codex]="OpenAI Codex CLI"
  [agy]="Google Antigravity"
  [gemini]="Google Gemini CLI"
  [cursor]="Cursor"
  [copilot]="GitHub Copilot (VS Code)"
  [opencode]="OpenCode"
  [windsurf]="Windsurf"
  [kiro]="Kiro"
  [cline]="Cline"
  [amp]="Amp"
  [roo]="Roo Code"
  [goose]="Goose"
)

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

list_agents() {
  local agent pair
  for agent in $(printf '%s\n' "${!MAPPINGS[@]}" | sort); do
    printf '%-9s %s\n' "$agent" "${DESCRIPTIONS[$agent]}"
    for pair in ${MAPPINGS[$agent]}; do
      printf '            %-34s -> .claude/%s\n' "${pair%%:*}" "${pair#*:}"
    done
  done
}

resolve_agent() {
  local name="${1,,}"
  name="${ALIASES[$name]:-$name}"
  if [[ -z "${MAPPINGS[$name]:-}" ]]; then
    echo "error: unknown agent '$1' (see --list)" >&2
    return 1
  fi
  echo "$name"
}

# True if $ROOT/.claude is (or resolves to) this .claude/ directory.
local_claude_ok() {
  [[ -e "$ROOT/.claude" && "$(readlink -f "$ROOT/.claude")" == "$CLAUDE_DIR" ]]
}

link_one() {
  local link="$ROOT/$1" target="$CLAUDE_DIR/$2"
  [[ "$2" == "." ]] && target="$CLAUDE_DIR"
  if [[ ! -e "$target" ]]; then
    echo "  skip    $1 (no .claude/$2)"
    return
  fi
  if [[ -e "$link" && "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
    echo "  ok      $1"
    return
  fi
  if [[ -L "$link" ]]; then
    echo "  WARN    $1 is a symlink to $(readlink "$link") — left untouched" >&2
    return
  fi
  if [[ -e "$link" ]]; then
    echo "  WARN    $1 already exists as a real file/dir — left untouched" >&2
    return
  fi
  mkdir -p "$(dirname "$link")"
  if [[ $VIA_LOCAL -eq 1 && "$2" != "." ]]; then
    # Relative path through $ROOT/.claude (ln -r would resolve that symlink).
    ln -s "$(realpath -sm --relative-to="$(dirname "$link")" "$ROOT/.claude/$2")" "$link"
  else
    ln -sr "$target" "$link"
  fi
  echo "  linked  $1 -> $(readlink "$link")"
}

unlink_one() {
  local link="$ROOT/$1" target="$CLAUDE_DIR/$2" dir
  [[ "$2" == "." ]] && target="$CLAUDE_DIR"
  # Only remove links that point back into .claude/ — never user files.
  if [[ -L "$link" && "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
    rm "$link"
    echo "  removed $1"
    # Drop the parent dir (e.g. .codex/) if this left it empty.
    dir="$(dirname "$link")"
    if [[ "$dir" != "$ROOT" ]]; then rmdir --ignore-fail-on-non-empty "$dir"; fi
  fi
}

# True if any agent link still points into .claude/ (the .claude link is in use).
any_agent_link_left() {
  local agent pair link
  for agent in "${!MAPPINGS[@]}"; do
    for pair in ${MAPPINGS[$agent]}; do
      link="$ROOT/${pair%%:*}"
      [[ -L "$link" && "$(readlink -f "$link")" == "$(readlink -f "$CLAUDE_DIR/${pair#*:}")" ]] && return 0
    done
  done
  return 1
}

main() {
  local action=link agents=() dest="" agent pair
  [[ $# -eq 0 ]] && { usage; exit 1; }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --list) list_agents; exit 0 ;;
      -r|--remove) action=unlink ;;
      -l|--location)
        [[ $# -lt 2 ]] && { echo "error: $1 needs a <path>" >&2; exit 1; }
        dest="$2"; shift ;;
      all) agents+=("${!MAPPINGS[@]}") ;;
      *) agents+=("$(resolve_agent "$1")") ;;
    esac
    shift
  done
  [[ ${#agents[@]} -eq 0 ]] && { echo "error: no agent given" >&2; exit 1; }

  if [[ -n "$dest" ]]; then
    [[ -d "$dest" ]] || { echo "error: '$dest' is not a directory" >&2; exit 1; }
    ROOT="$(cd "$dest" && pwd)"
  else
    ROOT="$PWD"
  fi
  # Never drop AGENTS.md etc. inside .claude/ itself.
  if [[ "$(readlink -f "$ROOT")/" == "$CLAUDE_DIR/"* ]]; then
    echo "error: target '$ROOT' is inside $CLAUDE_DIR — run from the workspace root or use -l <path>" >&2
    exit 1
  fi
  echo "target: $ROOT"

  if [[ -n "$dest" && $action == link ]]; then
    echo ".claude:"
    link_one ".claude" "."
  fi
  local_claude_ok && VIA_LOCAL=1

  for agent in $(printf '%s\n' "${agents[@]}" | sort -u); do
    echo "$agent (${DESCRIPTIONS[$agent]}):"
    for pair in ${MAPPINGS[$agent]}; do
      "${action}_one" "${pair%%:*}" "${pair#*:}"
    done
  done

  # With -l, drop the .claude link once no agent link uses it any more.
  if [[ -n "$dest" && $action == unlink && -L "$ROOT/.claude" ]] && ! any_agent_link_left; then
    echo ".claude:"
    unlink_one ".claude" "."
  fi
}

main "$@"
