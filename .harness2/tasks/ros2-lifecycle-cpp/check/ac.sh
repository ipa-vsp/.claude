# ac.sh — acceptance-criteria tally for harness2 check scripts (copied into every task's check/).
# harness2 reads the last stdout line {"n_passed", "n_criteria", "notes"} as a partial score.
# Usage in check/run.sh:
#   source "$(dirname "$0")/ac.sh"
#   ac "builds" cmake --build build
#   ac_done
# Command output goes to $AC_LOG and is replayed on stderr so harness2 keeps the tail.

AC_PASS=0
AC_TOTAL=0
AC_FAILED=()
AC_LOG="$(mktemp)"

ac() {
  local name="$1"; shift
  AC_TOTAL=$((AC_TOTAL + 1))
  echo "### AC: $name" >>"$AC_LOG"
  if "$@" >>"$AC_LOG" 2>&1; then
    AC_PASS=$((AC_PASS + 1))
    echo "PASS  $name"
  else
    AC_FAILED+=("$name")
    echo "FAIL  $name"
  fi
}

# Grep-style negative check: passes when the pattern does NOT occur.
absent() { ! grep -rnE "$@"; }

ac_done() {
  tail -c 6000 "$AC_LOG" >&2
  local notes="all criteria met"
  ((${#AC_FAILED[@]})) && notes="failed: $(IFS=';'; echo "${AC_FAILED[*]}")"
  notes="${notes//\"/\'}"
  printf '{"n_passed": %d, "n_criteria": %d, "notes": "%s"}\n' "$AC_PASS" "$AC_TOTAL" "$notes"
  rm -f "$AC_LOG"
  [[ "$AC_PASS" -eq "$AC_TOTAL" ]]
}
