I need a small, dependency-free thread pool crate for our sensor preprocessing tool. Create it as
`output/worker_pool/` (library crate `worker_pool`, edition 2024).

API:

```rust
pub struct ThreadPool { /* ... */ }
pub enum PoolError { ZeroWorkers, ShutDown }   // implements std::error::Error + Display

impl ThreadPool {
    pub fn new(workers: usize) -> Result<ThreadPool, PoolError>;          // 0 -> ZeroWorkers
    pub fn execute<F>(&self, job: F) -> Result<(), PoolError>
        where F: FnOnce() + Send + 'static;
    pub fn workers(&self) -> usize;
    pub fn shutdown(self);   // finishes every job already queued, then joins all threads
}
// Dropping the pool behaves like shutdown().
```

Requirements:

- Channel-based (std only). `#![forbid(unsafe_code)]` at the crate root.
- A job that panics must not shrink the pool or lose later jobs. A pool with one worker keeps
  processing after a panicking job.
- No `thread::sleep` anywhere, including tests. Synchronise with channels, barriers or condvars.
- Tests for: every queued job finishing on shutdown/drop, panic resilience, real parallelism
  (N workers can run N blocking jobs at once), and the zero-worker error.
- Clean under `cargo clippy --all-targets -- -D warnings`.

Please don't leave a `target/` directory in `output/`.
