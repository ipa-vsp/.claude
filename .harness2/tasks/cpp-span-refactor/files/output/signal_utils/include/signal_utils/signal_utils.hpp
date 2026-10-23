#pragma once
#include <cstddef>

namespace signal_utils {

// Arithmetic mean of n samples. Returns 0 for n == 0.
double mean(const double * data, std::size_t n);

// Multiply every sample by k in place.
void scale(double * data, std::size_t n, double k);

// Index of the largest element, or -1 if n == 0.
int argmax(const int * data, std::size_t n);

// Moving average with the given window; writes n - window + 1 values to out.
// Returns the number of values written, 0 if window == 0 or window > n.
std::size_t moving_average(const double * in, std::size_t n, std::size_t window, double * out);

}  // namespace signal_utils
