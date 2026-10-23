#include <gtest/gtest.h>
#include <ringbuffer/ring_buffer.hpp>

#include <atomic>
#include <memory>
#include <numeric>
#include <stdexcept>
#include <thread>
#include <type_traits>
#include <vector>

using ringbuffer::RingBuffer;

static_assert(!std::is_copy_constructible_v<RingBuffer<int>>);
static_assert(!std::is_move_constructible_v<RingBuffer<int>>);

TEST(HiddenRing, ZeroCapacityThrows) {
  EXPECT_THROW(RingBuffer<int>{0}, std::invalid_argument);
}

TEST(HiddenRing, FifoAndBounds) {
  RingBuffer<int> rb{3};
  EXPECT_EQ(rb.capacity(), 3U);
  EXPECT_TRUE(rb.empty());
  EXPECT_TRUE(rb.try_push(1));
  EXPECT_TRUE(rb.try_push(2));
  EXPECT_TRUE(rb.try_push(3));
  EXPECT_FALSE(rb.try_push(4));
  EXPECT_EQ(rb.size(), 3U);
  EXPECT_EQ(rb.try_pop(), 1);
  EXPECT_TRUE(rb.try_push(4));
  EXPECT_EQ(rb.try_pop(), 2);
  EXPECT_EQ(rb.try_pop(), 3);
  EXPECT_EQ(rb.try_pop(), 4);
  EXPECT_FALSE(rb.try_pop().has_value());
}

TEST(HiddenRing, MoveOnly) {
  RingBuffer<std::unique_ptr<int>> rb{2};
  EXPECT_TRUE(rb.try_push(std::make_unique<int>(5)));
  EXPECT_TRUE(rb.push(std::make_unique<int>(6)));
  auto a = rb.pop();
  ASSERT_TRUE(a.has_value());
  EXPECT_EQ(**a, 5);
  auto b = rb.try_pop();
  ASSERT_TRUE(b.has_value());
  EXPECT_EQ(**b, 6);
}

TEST(HiddenRing, CloseDrainsThenNullopt) {
  RingBuffer<int> rb{4};
  ASSERT_TRUE(rb.push(1));
  ASSERT_TRUE(rb.push(2));
  rb.close();
  EXPECT_FALSE(rb.push(3));
  EXPECT_FALSE(rb.try_push(3));
  EXPECT_EQ(rb.pop(), 1);
  EXPECT_EQ(rb.pop(), 2);
  EXPECT_FALSE(rb.pop().has_value());
}

TEST(HiddenRing, CloseWakesBlockedConsumersAndProducers) {
  RingBuffer<int> empty{1};
  RingBuffer<int> full{1};
  ASSERT_TRUE(full.try_push(0));
  std::atomic<int> woke{0};
  std::vector<std::thread> ts;
  for (int i = 0; i < 3; ++i) {
    ts.emplace_back([&] { if (!empty.pop().has_value()) { ++woke; } });
    ts.emplace_back([&] { if (!full.push(1)) { ++woke; } });
  }
  empty.close();
  full.close();
  for (auto & t : ts) { t.join(); }
  EXPECT_EQ(woke.load(), 6);
}

TEST(HiddenRing, MpmcStress) {
  constexpr int kProducers = 4;
  constexpr int kPerProducer = 20000;
  RingBuffer<int> rb{16};
  std::atomic<long long> sum{0};
  std::atomic<int> count{0};
  std::vector<std::thread> consumers;
  for (int c = 0; c < 4; ++c) {
    consumers.emplace_back([&] {
      while (auto v = rb.pop()) { sum += *v; ++count; }
    });
  }
  std::vector<std::thread> producers;
  for (int p = 0; p < kProducers; ++p) {
    producers.emplace_back([&] {
      for (int i = 1; i <= kPerProducer; ++i) { ASSERT_TRUE(rb.push(i)); }
    });
  }
  for (auto & t : producers) { t.join(); }
  rb.close();
  for (auto & t : consumers) { t.join(); }
  EXPECT_EQ(count.load(), kProducers * kPerProducer);
  EXPECT_EQ(sum.load(), static_cast<long long>(kProducers) * kPerProducer * (kPerProducer + 1) / 2);
}
