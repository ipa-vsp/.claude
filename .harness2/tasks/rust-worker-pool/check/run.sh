#!/usr/bin/env bash
# Hidden acceptance check for rust-worker-pool. cwd = workspace; crate in output/worker_pool.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
cd output/worker_pool || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/worker_pool missing"}'; exit 1; }
export CARGO_TARGET_DIR="$(mktemp -d)" CARGO_TERM_COLOR=never
rm -rf target
ac "cargo build" cargo build --quiet
ac "clippy --all-targets -D warnings" cargo clippy --quiet --all-targets -- -D warnings
ac "own tests pass" timeout 300 cargo test --quiet
ac "own tests cover >= 4 cases" bash -c '[ "$(cargo test --quiet -- --list 2>/dev/null | grep -c ": test$")" -ge 4 ]'
mkdir -p tests && cp "$CHECK/hidden.rs" tests/zz_hidden_acceptance.rs
ac "hidden behaviour tests pass (x5)" bash -c 'for i in 1 2 3 4 5; do timeout 120 cargo test --quiet --test zz_hidden_acceptance || exit 1; done'
rm -f tests/zz_hidden_acceptance.rs
ac "forbid(unsafe_code) at crate root" grep -qE '^#!\[forbid\(unsafe_code\)\]' src/lib.rs
ac "no thread::sleep anywhere" absent 'sleep\(' src tests
rm -rf "$CARGO_TARGET_DIR"
ac_done
