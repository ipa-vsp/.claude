#!/usr/bin/env bash
# h2_lab_sync.sh — keep the harness2 skills lab (AGENTS.md + .agents/skills/) in step with
# this repo's CLAUDE.md + skills/.
#
# harness2's Antigravity substrate tunes AGENTS.md and .agents/skills/, refuses symlinks, and
# rollouts only see committed files, so the lab holds real copies. Excluded skills are never
# mirrored and never copied back.
#
# Usage (from anywhere):
#   .claude/scripts/h2_lab_sync.sh to-lab     skills/ -> .agents/skills/, CLAUDE.md -> AGENTS.md
#   .claude/scripts/h2_lab_sync.sh from-lab   .agents/skills/ -> skills/ (CLAUDE.md is left alone)
#   .claude/scripts/h2_lab_sync.sh check      exit 1 if the lab and skills/ differ

set -euo pipefail

CLAUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$CLAUDE_DIR/skills"
LAB="$CLAUDE_DIR/.agents/skills"
EXCLUDED=(rea-wiki-vault harness2-setup)

die() { echo "error: $*" >&2; exit 1; }

is_excluded() {
  local name="$1" x
  for x in "${EXCLUDED[@]}"; do [[ "$name" == "$x" ]] && return 0; done
  return 1
}

rsync_excludes() {
  local x
  for x in "${EXCLUDED[@]}"; do printf -- '--exclude=/%s/\n' "$x"; done
}

# CLAUDE.md as the lab sees it. Skill files are copied verbatim (rewriting them is not
# round-trip safe); only the index's .claude/skills/ paths point at the lab.
lab_agents_md() {
  sed 's#\.claude/skills/#.agents/skills/#g' "$CLAUDE_DIR/CLAUDE.md"
}

cmd_to_lab() {
  mkdir -p "$LAB"
  mapfile -t excl < <(rsync_excludes)
  rsync -a --delete --no-links "${excl[@]}" "$SRC/" "$LAB/"
  lab_agents_md > "$CLAUDE_DIR/AGENTS.md"
  local chars
  chars=$(wc -c < "$CLAUDE_DIR/AGENTS.md")
  (( chars <= 24000 )) || die "AGENTS.md is $chars chars; Antigravity caps it at 24000"
  echo "lab updated: $(find "$LAB" -mindepth 1 -maxdepth 1 -type d | wc -l) skills, AGENTS.md $chars chars"
}

cmd_from_lab() {
  [[ -d "$LAB" ]] || die "no lab at $LAB; run to-lab first"
  local d name
  for d in "$LAB"/*/; do
    name="$(basename "$d")"
    is_excluded "$name" && die "lab contains excluded skill '$name'; refusing to copy back"
  done
  mapfile -t excl < <(rsync_excludes)
  # Excluded skills in skills/ are protected from --delete by the filter.
  rsync -a --delete "${excl[@]}" "$LAB/" "$SRC/"
  git -C "$CLAUDE_DIR" --no-pager diff --stat -- skills/
  if ! diff -q <(lab_agents_md) "$CLAUDE_DIR/AGENTS.md" >/dev/null; then
    echo "AGENTS.md differs from CLAUDE.md; merge by hand:"
    diff -u <(lab_agents_md) "$CLAUDE_DIR/AGENTS.md" || true
  fi
}

cmd_check() {
  [[ -d "$LAB" ]] || die "no lab at $LAB"
  local rc=0 x
  mapfile -t excl < <(rsync_excludes)
  # Dry-run with --delete lists every path that to-lab would change.
  if [[ -n "$(rsync -a -n -i --delete --no-links "${excl[@]}" "$SRC/" "$LAB/")" ]]; then
    rsync -a -n -i --delete --no-links "${excl[@]}" "$SRC/" "$LAB/"
    rc=1
  fi
  for x in "${EXCLUDED[@]}"; do
    [[ -e "$LAB/$x" ]] && { echo "excluded skill present in lab: $x"; rc=1; }
  done
  diff -q <(lab_agents_md) "$CLAUDE_DIR/AGENTS.md" >/dev/null \
    || { echo "AGENTS.md differs from CLAUDE.md"; rc=1; }
  (( rc == 0 )) && echo "lab in sync"
  return "$rc"
}

case "${1:-}" in
  to-lab) cmd_to_lab ;;
  from-lab) cmd_from_lab ;;
  check) cmd_check ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
