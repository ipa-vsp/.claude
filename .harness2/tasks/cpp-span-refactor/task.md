`output/signal_utils/` still has a C-style pointer + length API, and we keep getting
out-of-bounds bugs from callers passing the wrong length. Please modernise it in place for C++20:

- Replace every pointer + size parameter with `std::span`. Inputs are `std::span<const T>`, and
  in-place or output buffers are `std::span<T>`. Keep the function names and semantics
  (`mean`, `scale`, `argmax`, `moving_average`).
- `argmax` returns `std::optional<std::size_t>` (empty for empty input) instead of `-1`.
- `moving_average` throws `std::invalid_argument` if `out` is too small for the result. Window 0
  or a window larger than the input still writes nothing and returns 0.
- Mark pure functions `[[nodiscard]]`, and fix any latent bugs or warnings you find on the way
  (the build must be clean with `-Wall -Wextra -Wpedantic -Wconversion -Werror`).
- Update and extend the GTest tests, covering the edge cases.

Don't leave a build directory in `output/`.
