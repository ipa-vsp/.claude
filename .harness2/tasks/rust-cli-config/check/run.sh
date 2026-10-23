#!/usr/bin/env bash
# Hidden acceptance check for rust-cli-config. cwd = workspace; crate in output/ctlcfg.
source "$(dirname "$0")/ac.sh"
CASES="$PWD/check/cases"
cd output/ctlcfg || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/ctlcfg missing"}'; exit 1; }
export CARGO_TARGET_DIR="$(mktemp -d)" CARGO_TERM_COLOR=never
rm -rf target
BIN="$CARGO_TARGET_DIR/debug/ctlcfg"
ac "cargo build" cargo build --quiet
ac "clippy --all-targets -D warnings" cargo clippy --quiet --all-targets -- -D warnings
ac "own tests pass" timeout 300 cargo test --quiet
ac "valid file: check prints ok, exit 0" bash -c "[ \"\$('$BIN' check '$CASES/good.cfg')\" = ok ]"
ac "show --json normalises" bash -c "'$BIN' show '$CASES/good.cfg' --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d==dict(rate_hz=500.0,kp=12.5,ki=0.0,kd=0.3,joints=[\"j1\",\"j2\",\"j3\"]), d'"
ac "invalid file: exit 2, every error reported with line" bash -c "'$BIN' check '$CASES/bad.cfg' 2>err.txt; rc=\$?; [ \$rc -eq 2 ] && for n in 1 2 3 4; do grep -q \"^error: line \$n:\" err.txt || exit 1; done"
ac "missing required key -> line 0" bash -c "'$BIN' check '$CASES/missing.cfg' 2>err.txt; [ \$? -eq 2 ] && grep -q '^error: line 0:.*joints' err.txt && grep -q '^error: line 0:.*rate_hz' err.txt"
ac "duplicate key reported" bash -c "'$BIN' check '$CASES/dup.cfg' 2>err.txt; [ \$? -eq 2 ] && grep -q '^error: line 2:' err.txt"
ac "unreadable file: exit 1 naming path" bash -c "'$BIN' check /nonexistent/x.cfg 2>err.txt; [ \$? -eq 1 ] && grep -q '/nonexistent/x.cfg' err.txt"
ac "no unwrap/expect/panic in non-test code" bash -c '! for f in $(find src -name "*.rs"); do awk "/#\\[cfg\\(test\\)\\]/{exit} {print FILENAME\":\"FNR\": \"\$0}" "$f"; done | grep -E "\.unwrap\(\)|\.expect\(|panic!\("'
rm -f err.txt; rm -rf "$CARGO_TARGET_DIR"
ac_done
