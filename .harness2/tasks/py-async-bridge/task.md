Our sensor drivers run in plain threads, but the new perception service is asyncio. Please write a
small typed library `async_bridge` in `output/async_bridge/` (package dir
`output/async_bridge/async_bridge/`, tests in `output/async_bridge/tests/`) that hands items from
threads to a coroutine consumer:

```python
class BridgeClosed(Exception): ...

class ChannelBridge(Generic[T]):
    def __init__(self, loop: asyncio.AbstractEventLoop, maxsize: int = 0) -> None: ...
    def put(self, item: T) -> None: ...          # thread-safe, callable from any thread
    def close(self) -> None: ...                 # thread-safe; idempotent
    async def get(self) -> T: ...                # raises BridgeClosed once closed AND drained
    def __aiter__(self) -> AsyncIterator[T]: ... # `async for item in bridge` ends when closed+drained
```

- `put` after `close` raises `BridgeClosed`. Items are delivered in order, and none are lost.
- When `maxsize > 0`, `put` blocks the calling thread while the bridge is full (back-pressure), but
  it must never block the event loop thread.
- Full type hints. It must pass `mypy --strict` and flake8 (pycodestyle + pyflakes rules, max line
  length 100).
- pytest tests (you can drive the loop with `asyncio.run` in the tests) covering ordering, close
  semantics, async iteration, multiple producer threads, and back-pressure. No `time.sleep` for
  synchronisation.
