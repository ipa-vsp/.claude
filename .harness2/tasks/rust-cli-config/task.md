Please build a small Rust CLI, `ctlcfg`, that validates and prints our controller config files. Make
it a cargo package in `output/ctlcfg/` (edition 2024) with a library part plus a thin `main.rs`. Use
`clap` with derive.

Config format: one `key = value` per line, with `#` comments and blank lines allowed. Keys:

- `rate_hz`: float, > 0, required
- `kp`, `ki`, `kd`: floats, >= 0, default 0
- `joints`: comma-separated names, non-empty, unique, whitespace-trimmed, required

Unknown keys and duplicate keys are errors.

Commands:

- `ctlcfg check <FILE>` prints `ok` and exits 0 when valid. Otherwise it prints **every** problem
  to stderr as `error: line <N>: <message>` (use line 0 for a missing required key) and exits
  with code 2.
- `ctlcfg show <FILE> [--json]` prints the normalised config. With `--json`, print one JSON object
  `{"rate_hz": .., "kp": .., "ki": .., "kd": .., "joints": [..]}`. An invalid file behaves like
  `check`.
- A file that can't be read exits 1 with a message naming the path.

The library returns typed errors, with no `unwrap`/`expect`/`panic!` in non-test code. Include unit
tests and integration tests that run the binary. It must be clean under
`cargo clippy --all-targets -- -D warnings`. Don't leave `target/` in `output/`.
