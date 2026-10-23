#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <thread>

#include "event_bus/event_bus.hpp"

using event_bus::Event;
using event_bus::EventBus;

TEST(EventBus, DeliversPublishedEvent) {
  EventBus bus;
  std::atomic<int> received{0};
  bus.subscribe([&](const Event & e) { received += e.id; });
  bus.publish({7, "test"});
  std::this_thread::sleep_for(std::chrono::milliseconds(10));
  EXPECT_EQ(received.load(), 7);
}

TEST(EventBus, MultipleSubscribers) {
  EventBus bus;
  std::atomic<int> a{0};
  std::atomic<int> b{0};
  bus.subscribe([&](const Event &) { ++a; });
  bus.subscribe([&](const Event &) { ++b; });
  for (int i = 0; i < 5; ++i) {
    bus.publish({i, "t"});
  }
  std::this_thread::sleep_for(std::chrono::milliseconds(50));
  EXPECT_EQ(a.load(), 5);
  EXPECT_EQ(b.load(), 5);
}
