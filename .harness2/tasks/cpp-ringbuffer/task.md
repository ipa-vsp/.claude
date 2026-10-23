I need a header-only, thread-safe, fixed-capacity ring buffer for passing samples between our driver
thread and the control thread. Please create it as a small CMake project in `output/ringbuffer/`.

- Header `include/ringbuffer/ring_buffer.hpp`, `namespace ringbuffer`, class template
  `RingBuffer<T>`:
  - `explicit RingBuffer(std::size_t capacity)`. Throws `std::invalid_argument` if capacity is 0.
  - `bool try_push(T value)` returns false when full or closed.
  - `std::optional<T> try_pop()` returns nullopt when empty.
  - `bool push(T value)` blocks while full and returns false once closed.
  - `std::optional<T> pop()` blocks while empty. It returns nullopt only when the buffer is closed
    and drained.
  - `void close()` wakes every blocked caller. Items still queued can be popped after close.
  - `std::size_t size() const`, `bool empty() const`, `std::size_t capacity() const noexcept`.
  - It must work with move-only `T`, for example `std::unique_ptr<int>`. Not copyable, not movable.
- C++20, no raw `new`/`delete`, and follow the C++ Core Guidelines.
- `CMakeLists.txt` with an INTERFACE library target `ringbuffer::ringbuffer`, plus GoogleTest tests in
  `tests/` registered with CTest. Cover FIFO order, full/empty behaviour, close semantics,
  move-only types, and a multi-producer/multi-consumer stress test. Don't use sleeps to
  synchronise.
- It must build cleanly with `-Wall -Wextra -Wpedantic -Werror`.

Don't leave a build directory in `output/`.
