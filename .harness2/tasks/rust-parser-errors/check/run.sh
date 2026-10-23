#!/usr/bin/env bash
# Hidden acceptance check for rust-parser-errors. cwd = workspace; crate in output/joint_limits.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
cd output/joint_limits || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/joint_limits missing"}'; exit 1; }
export CARGO_TARGET_DIR="$(mktemp -d)" CARGO_TERM_COLOR=never
rm -rf target
ac "cargo build" cargo build --quiet
ac "clippy --all-targets -D warnings" cargo clippy --quiet --all-targets -- -D warnings
ac "clippy pedantic on lib" cargo clippy --quiet --lib -- -D warnings -W clippy::pedantic
ac "own tests pass" cargo test --quiet
ac "own tests cover >= 7 cases" bash -c '[ "$(cargo test --quiet -- --list 2>/dev/null | grep -c ": test$")" -ge 7 ]'
cp "$CHECK/hidden.rs" tests/zz_hidden_acceptance.rs
ac "hidden API tests pass" cargo test --quiet --test zz_hidden_acceptance
rm -f tests/zz_hidden_acceptance.rs
# Library code = src/ up to the first #[cfg(test)].
ac "no unwrap/expect/panic in library code" bash -c '! for f in src/*.rs src/**/*.rs; do [ -f "$f" ] && awk "/#\\[cfg\\(test\\)\\]/{exit} {print FILENAME\":\"FNR\": \"\$0}" "$f"; done | grep -E "\.unwrap\(\)|\.expect\(|panic!\(|unreachable!\(|todo!\(|unimplemented!\("'
rm -rf "$CARGO_TARGET_DIR"
ac_done
