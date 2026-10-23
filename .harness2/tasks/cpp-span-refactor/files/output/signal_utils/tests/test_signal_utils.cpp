#include <gtest/gtest.h>
#include <vector>
#include "signal_utils/signal_utils.hpp"

TEST(SignalUtils, Mean) {
  std::vector<double> v{1.0, 2.0, 3.0};
  EXPECT_DOUBLE_EQ(signal_utils::mean(v.data(), v.size()), 2.0);
}

TEST(SignalUtils, MovingAverage) {
  std::vector<double> v{1.0, 2.0, 3.0, 4.0};
  std::vector<double> out(3);
  EXPECT_EQ(signal_utils::moving_average(v.data(), v.size(), 2, out.data()), 3U);
  EXPECT_DOUBLE_EQ(out[2], 3.5);
}
