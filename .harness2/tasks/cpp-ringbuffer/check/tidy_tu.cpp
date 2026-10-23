#include <ringbuffer/ring_buffer.hpp>
#include <memory>
template class ringbuffer::RingBuffer<int>;
template class ringbuffer::RingBuffer<std::unique_ptr<int>>;
