#include <gtest/gtest.h>

#include <atomic>
#include <thread>
#include <vector>

#include "event_bus/event_bus.hpp"

using event_bus::Event;
using event_bus::EventBus;

TEST(HiddenBus, DrainsEverythingOnDestruction) {
  std::atomic<int> count{0};
  {
    EventBus bus;
    bus.subscribe([&](const Event &) { ++count; });
    std::vector<std::thread> producers;
    for (int p = 0; p < 4; ++p) {
      producers.emplace_back([&bus, p] {
        for (int i = 0; i < 1000; ++i) { bus.publish({p * 1000 + i, "load"}); }
      });
    }
    for (auto & t : producers) { t.join(); }
  }
  EXPECT_EQ(count.load(), 4000);
}

TEST(HiddenBus, OrderPreservedPerPublisher) {
  std::vector<int> seen;
  {
    EventBus bus;
    bus.subscribe([&](const Event & e) { seen.push_back(e.id); });
    for (int i = 0; i < 500; ++i) { bus.publish({i, "order"}); }
  }
  ASSERT_EQ(seen.size(), 500U);
  for (int i = 0; i < 500; ++i) { EXPECT_EQ(seen[static_cast<std::size_t>(i)], i); }
}

TEST(HiddenBus, SubscribeWhileDispatching) {
  std::atomic<int> count{0};
  {
    EventBus bus;
    bus.subscribe([&](const Event &) { ++count; });
    std::thread publisher([&bus] {
      for (int i = 0; i < 2000; ++i) { bus.publish({i, "x"}); }
    });
    for (int i = 0; i < 50; ++i) { bus.subscribe([](const Event &) {}); }
    publisher.join();
  }
  EXPECT_EQ(count.load(), 2000);
}

TEST(HiddenBus, ManyShortLivedBuses) {
  for (int round = 0; round < 200; ++round) {
    std::atomic<int> count{0};
    {
      EventBus bus;
      bus.subscribe([&](const Event &) { ++count; });
      bus.publish({round, "short"});
    }
    ASSERT_EQ(count.load(), 1) << "round " << round;
  }
}
