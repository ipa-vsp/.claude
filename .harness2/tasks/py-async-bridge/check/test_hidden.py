import asyncio
import threading

import pytest

from async_bridge import BridgeClosed, ChannelBridge


def test_threads_to_async_in_order():
    async def main():
        bridge: ChannelBridge[int] = ChannelBridge(asyncio.get_running_loop())

        def produce():
            for i in range(2000):
                bridge.put(i)
            bridge.close()
        t = threading.Thread(target=produce)
        t.start()
        got = [x async for x in bridge]
        t.join()
        return got
    assert asyncio.run(main()) == list(range(2000))


def test_get_raises_after_close_and_drain():
    async def main():
        bridge: ChannelBridge[str] = ChannelBridge(asyncio.get_running_loop())
        bridge.put("a")
        bridge.close()
        bridge.close()
        assert await bridge.get() == "a"
        with pytest.raises(BridgeClosed):
            await bridge.get()
        with pytest.raises(BridgeClosed):
            bridge.put("b")
    asyncio.run(main())


def test_close_wakes_waiting_consumer():
    async def main():
        bridge: ChannelBridge[int] = ChannelBridge(asyncio.get_running_loop())
        waiter = asyncio.ensure_future(bridge.get())
        await asyncio.sleep(0)
        threading.Thread(target=bridge.close).start()
        with pytest.raises(BridgeClosed):
            await asyncio.wait_for(waiter, 5)
    asyncio.run(main())


def test_multiple_producers_backpressure():
    async def main():
        bridge: ChannelBridge[int] = ChannelBridge(asyncio.get_running_loop(), maxsize=4)

        def produce(base):
            for i in range(500):
                bridge.put(base + i)
        threads = [threading.Thread(target=produce, args=(k * 1000,)) for k in range(4)]
        for t in threads:
            t.start()
        got = []
        while len(got) < 2000:
            got.append(await asyncio.wait_for(bridge.get(), 10))
        for t in threads:
            t.join()
        assert sorted(got) == sorted(k * 1000 + i for k in range(4) for i in range(500))
        for k in range(4):
            mine = [x for x in got if k * 1000 <= x < k * 1000 + 500]
            assert mine == sorted(mine)
    asyncio.run(main())
