The `joint_limits` crate in `output/joint_limits/` panics on any malformed limits file, and that takes
down our whole bringup tool. Please make it a well-behaved library. Edit it in place.

- `parse(input: &str) -> Result<Vec<JointLimit>, ParseError>` and
  `parse_file(path: impl AsRef<Path>) -> Result<Vec<JointLimit>, ParseError>`.
- `ParseError` is a public enum that callers can `match` on. It implements `std::error::Error` and
  `Display`, it is `Send + Sync + 'static`, and it has these variants with exactly these fields
  (line numbers are 1-based):
  - `MissingField { line: usize, field: &'static str }`, where `field` is one of `"name"`, `"lower"`,
    `"upper"` or `"max_velocity"`
  - `InvalidNumber { line: usize, field: &'static str, value: String }`
  - `InvertedLimits { line: usize }`, for `lower >= upper`
  - `NonPositiveVelocity { line: usize }`
  - `DuplicateJoint { line: usize, name: String }`
  - `TrailingFields { line: usize }`, for more than 4 fields
  - `Io(std::io::Error)`, exposed through `source()`
- No `unwrap`, `expect` or `panic!` in non-test library code.
- Unit or integration tests for every variant.
- The crate must stay clean under `cargo clippy --all-targets -- -D warnings`, and under
  `cargo clippy -- -D warnings -W clippy::pedantic` for the library.

You may add well-known dependencies such as `thiserror` if you want. Please don't leave a `target/`
directory in `output/`.
