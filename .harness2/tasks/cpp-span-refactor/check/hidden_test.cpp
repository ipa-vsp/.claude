#include <gtest/gtest.h>
#include <array>
#include <optional>
#include <span>
#include <stdexcept>
#include <type_traits>
#include <vector>
#include "signal_utils/signal_utils.hpp"

using namespace signal_utils;

TEST(HiddenSpan, AcceptsContainers) {
  std::vector<double> v{2.0, 4.0};
  std::array<double, 3> a{1.0, 1.0, 4.0};
  EXPECT_DOUBLE_EQ(mean(v), 3.0);
  EXPECT_DOUBLE_EQ(mean(a), 2.0);
  EXPECT_DOUBLE_EQ(mean(std::span<const double>{}), 0.0);
  scale(v, 0.5);
  EXPECT_DOUBLE_EQ(v[1], 2.0);
}

TEST(HiddenSpan, ArgmaxOptional) {
  std::vector<int> v{3, 9, 9, -1};
  static_assert(std::is_same_v<decltype(argmax(std::span<const int>(v))), std::optional<std::size_t>>);
  EXPECT_EQ(argmax(v), std::optional<std::size_t>{1});
  EXPECT_FALSE(argmax(std::span<const int>{}).has_value());
}

TEST(HiddenSpan, MovingAverage) {
  std::vector<double> in{1.0, 2.0, 3.0, 4.0, 5.0};
  std::vector<double> out(3);
  EXPECT_EQ(moving_average(in, 3, out), 3U);
  EXPECT_DOUBLE_EQ(out[0], 2.0);
  EXPECT_DOUBLE_EQ(out[2], 4.0);
  std::vector<double> small(2);
  EXPECT_THROW(static_cast<void>(moving_average(in, 3, small)), std::invalid_argument);
  EXPECT_EQ(moving_average(in, 0, out), 0U);
  EXPECT_EQ(moving_average(in, 6, out), 0U);
}
