#!/usr/bin/env bash
# link-agents.sh — expose this .claude/ config to other coding agents via symlinks.
#
# Nothing is copied: every entry created is a relative symlink back into
# .claude/, so editing a skill/rule/agent here updates every agent at once.
# Links are created in the directory that contains .claude/ (the workspace root).
#
# Usage:
#   .claude/scripts/link-agents.sh <agent> [<agent> ...]   create links
#   .claude/scripts/link-agents.sh --remove <agent> ...    remove links
#   .claude/scripts/link-agents.sh --list                  show supported agents
#   .claude/scripts/link-agents.sh all                     every supported agent
#
# Example:
#   .claude/scripts/link-agents.sh codex agy

set -euo pipefail

CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(dirname "$CLAUDE_DIR")"

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

usage() { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

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

link_one() {
  local link="$ROOT/$1" target="$CLAUDE_DIR/$2"
  if [[ ! -e "$target" ]]; then
    echo "  skip    $1 (no .claude/$2)"
    return
  fi
  if [[ -L "$link" ]]; then
    if [[ "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
      echo "  ok      $1"
      return
    fi
    echo "  WARN    $1 is a symlink to $(readlink "$link") — left untouched" >&2
    return
  fi
  if [[ -e "$link" ]]; then
    echo "  WARN    $1 already exists as a real file/dir — left untouched" >&2
    return
  fi
  mkdir -p "$(dirname "$link")"
  ln -sr "$target" "$link"
  echo "  linked  $1 -> $(readlink "$link")"
}

unlink_one() {
  local link="$ROOT/$1" target="$CLAUDE_DIR/$2" dir
  # Only remove links that point back into .claude/ — never user files.
  if [[ -L "$link" && "$(readlink -f "$link")" == "$(readlink -f "$target")" ]]; then
    rm "$link"
    echo "  removed $1"
    # Drop the parent dir (e.g. .codex/) if this left it empty.
    dir="$(dirname "$link")"
    if [[ "$dir" != "$ROOT" ]]; then rmdir --ignore-fail-on-non-empty "$dir"; fi
  fi
}

main() {
  local action=link agents=() arg agent pair
  [[ $# -eq 0 ]] && { usage; exit 1; }

  for arg in "$@"; do
    case "$arg" in
      -h|--help) usage; exit 0 ;;
      -l|--list) list_agents; exit 0 ;;
      -r|--remove) action=unlink ;;
      all) agents+=("${!MAPPINGS[@]}") ;;
      *) agents+=("$(resolve_agent "$arg")") ;;
    esac
  done
  [[ ${#agents[@]} -eq 0 ]] && { echo "error: no agent given" >&2; exit 1; }

  for agent in $(printf '%s\n' "${agents[@]}" | sort -u); do
    echo "$agent (${DESCRIPTIONS[$agent]}):"
    for pair in ${MAPPINGS[$agent]}; do
      "${action}_one" "${pair%%:*}" "${pair#*:}"
    done
  done
}

main "$@"
