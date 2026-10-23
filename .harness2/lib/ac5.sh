#!/usr/bin/env bash
# ac5.sh — run-level AC5/AC6 for the skills lab: skill frontmatter hygiene, removal of outdated
# Lyrical APIs from ros2-control, Rust skills present and indexed.
#   .harness2/lib/ac5.sh [skills_dir] [index_file]   (default: .agents/skills AGENTS.md)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source .harness2/lib/ac.sh
SKILLS="${1:-.agents/skills}"
INDEX="${2:-AGENTS.md}"

frontmatter_ok() {
  local f d name
  for f in "$SKILLS"/*/SKILL.md; do
    d="$(basename "$(dirname "$f")")"
    name="$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$f")"
    [[ "$name" == "$d" ]] || { echo "$f: name '$name' != dir '$d'"; return 1; }
    awk '/^---$/{n++; next} n==1 && /^description:/{found=1} END{exit !found}' "$f" \
      || { echo "$f: no description"; return 1; }
  done
}

ac "AC5 every SKILL.md: name == dir, description present" frontmatter_ok
ac "AC5 ros2-control: no removed on_init(HardwareInfo)" absent 'on_init\(const hardware_interface::HardwareInfo' "$SKILLS/ros2-control"
ac "AC5 ros2-control: no ament_target_dependencies" absent 'ament_target_dependencies' "$SKILLS/ros2-control"
ac "AC5 ros2-control: no deprecated RealtimeBuffer" absent 'RealtimeBuffer|realtime_buffer\.hpp' "$SKILLS/ros2-control"
ac "AC5 excluded skills absent from lab" bash -c "[ ! -e '$SKILLS/rea-wiki-vault' ] && [ ! -e '$SKILLS/harness2-setup' ] || [ '$SKILLS' = skills ]"
ac "AC6 rust-patterns + rust-testing exist" test -f "$SKILLS/rust-patterns/SKILL.md" -a -f "$SKILLS/rust-testing/SKILL.md"
ac "AC6 rust skills indexed" bash -c "grep -q 'rust-patterns' '$INDEX' && grep -q 'rust-testing' '$INDEX'"
ac_done
