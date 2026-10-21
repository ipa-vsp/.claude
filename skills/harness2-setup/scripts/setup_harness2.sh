#!/usr/bin/env bash
# Set up Harness² (harness2-cli fork) for a project: install, init per agent, check.
# Never runs `harness2 run`, `apply`, `eval` or `login`: those spend quota, write files or open a browser.
#
#   setup_harness2.sh check   [--dir D]
#   setup_harness2.sh install [--upgrade] [--ref REF]
#   setup_harness2.sh init    <claude|codex|agy> [--dir D] [--model M] [--improver M]
#                             [--max-calls N] [--editable GLOBS] [--force]
#   setup_harness2.sh doctor  [--dir D]
set -euo pipefail

REPO_URL="https://github.com/ipa-vsp/harness2"
PYTHON_VERSION="3.12"  # harness2 supports 3.12–3.14; 3.12 kept as managed uv default
DEFAULT_MAX_CALLS=50

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
row() { printf '  %-14s %s\n' "$1" "$2"; }

cmd_check() {
  local dir="$1"
  echo "tools:"
  for bin in uv git harness2 claude codex agy; do
    if have "$bin"; then
      row "$bin" "$("$bin" --version 2>/dev/null | head -n1 || echo installed)"
    else
      row "$bin" "MISSING"
    fi
  done
  if have harness2; then
    echo "logins (harness2 login --json):"
    harness2 --json login 2>/dev/null | sed 's/^/  /' || echo "  (could not read)"
  fi
  echo "project: $dir"
  if git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    row "git" "ok ($(git -C "$dir" rev-parse --abbrev-ref HEAD), $(git -C "$dir" status --porcelain | wc -l) uncommitted path(s))"
  else
    row "git" "NOT A GIT REPO (harness2 runs need git worktrees)"
  fi
  if [[ -f "$dir/.harness2/config.toml" ]]; then
    row ".harness2" "initialised"
  else
    row ".harness2" "not initialised"
  fi
}

cmd_install() {
  local upgrade="$1" ref="$2"
  have uv || die "uv is not on PATH"
  have git || die "git is not on PATH"
  local spec="git+${REPO_URL}"
  [[ -n "$ref" ]] && spec="${spec}@${ref}"
  if have harness2 && [[ "$upgrade" != 1 && -z "$ref" ]]; then
    echo "harness2 $(harness2 --version) already installed; pass --upgrade to reinstall from ${REPO_URL}"
    return 0
  fi
  uv tool install --force --python "$PYTHON_VERSION" "$spec"
  echo "installed harness2 $(harness2 --version)"
  echo "pinned commit: $(git ls-remote "$REPO_URL" "${ref:-HEAD}" | cut -f1)"
}

cmd_init() {
  local agent="$1" dir="$2" model="$3" improver="$4" max_calls="$5" editable="$6" force="$7"
  have harness2 || die "harness2 is not installed; run: $0 install"
  git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1 || die "$dir is not a git repository"
  if [[ -f "$dir/.harness2/config.toml" && "$force" != 1 ]]; then
    die "$dir/.harness2/config.toml exists; inspect it, then rerun with --force to overwrite"
  fi
  local h=(harness2 -C "$dir")
  local force_flag=()
  [[ "$force" == 1 ]] && force_flag=(--force)
  case "$agent" in
    claude)
      have claude || die "claude is not on PATH"
      "${h[@]}" init --yes "${force_flag[@]}" --executor claude --auth login
      ;;
    codex)
      have codex || die "codex is not on PATH"
      "${h[@]}" init --yes "${force_flag[@]}" --executor codex --auth login
      ;;
    agy|antigravity)
      have agy || die "agy is not on PATH"
      "${h[@]}" init --yes "${force_flag[@]}" --executor antigravity --auth login
      ;;
    *) die "agent must be claude, codex or agy (got '$agent')" ;;
  esac
  [[ -n "$model" ]] && "${h[@]}" config set executor.model "$model"
  [[ -n "$improver" ]] && "${h[@]}" config set improver.model "$improver"
  # Subscription quota guardrails: one rollout and one model session at a time, capped calls.
  "${h[@]}" config set run.max_calls "$max_calls"
  "${h[@]}" config set run.phase_width 1
  "${h[@]}" config set run.proposer_concurrency 1
  echo
  "${h[@]}" config show --origin
  echo
  echo "next: harness2 -C $dir task new <id> [--check CMD], write task.md, then: $0 doctor --dir $dir"
  [[ "$agent" == codex ]] && echo "codex needs a one-time login for harness2: harness2 login codex (opens a browser)"
  return 0
}

cmd_doctor() {
  local dir="$1"
  have harness2 || die "harness2 is not installed; run: $0 install"
  harness2 -C "$dir" doctor
}

main() {
  [[ $# -ge 1 ]] || { sed -n '2,9p' "$0"; exit 2; }
  local sub="$1"; shift
  local dir="$PWD" agent="" model="" improver="" max_calls="$DEFAULT_MAX_CALLS"
  local editable="" force=0 upgrade=0 ref=""
  if [[ "$sub" == init ]]; then
    [[ $# -ge 1 ]] || die "init needs an agent: claude, codex or agy"
    agent="$1"; shift
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) dir="$2"; shift 2 ;;
      --model) model="$2"; shift 2 ;;
      --improver) improver="$2"; shift 2 ;;
      --max-calls) max_calls="$2"; shift 2 ;;
      --editable) editable="$2"; shift 2 ;;
      --ref) ref="$2"; shift 2 ;;
      --force) force=1; shift ;;
      --upgrade) upgrade=1; shift ;;
      *) die "unknown option: $1" ;;
    esac
  done
  dir="$(cd "$dir" && pwd)"
  case "$sub" in
    check) cmd_check "$dir" ;;
    install) cmd_install "$upgrade" "$ref" ;;
    init) cmd_init "$agent" "$dir" "$model" "$improver" "$max_calls" "$editable" "$force" ;;
    doctor) cmd_doctor "$dir" ;;
    *) die "unknown command: $sub (check | install | init | doctor)" ;;
  esac
}

main "$@"
