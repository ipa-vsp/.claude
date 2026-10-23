#include "signal_utils/signal_utils.hpp"

namespace signal_utils {

double mean(const double * data, std::size_t n) {
  if (n == 0) return 0.0;
  double sum = 0.0;
  for (std::size_t i = 0; i < n; ++i) sum += data[i];
  return sum / n;
}

void scale(double * data, std::size_t n, double k) {
  for (std::size_t i = 0; i < n; ++i) data[i] *= k;
}

int argmax(const int * data, std::size_t n) {
  if (n == 0) return -1;
  int best = 0;
  for (std::size_t i = 1; i < n; ++i) {
    if (data[i] > data[best]) best = i;
  }
  return best;
}

std::size_t moving_average(const double * in, std::size_t n, std::size_t window, double * out) {
  if (window == 0 || window > n) return 0;
  for (std::size_t i = 0; i + window <= n; ++i) {
    out[i] = mean(in + i, window);
  }
  return n - window + 1;
}

}  // namespace signal_utils
