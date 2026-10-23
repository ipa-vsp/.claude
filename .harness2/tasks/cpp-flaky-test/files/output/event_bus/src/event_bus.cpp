#include "event_bus/event_bus.hpp"

#include <chrono>
#include <utility>

namespace event_bus {

EventBus::EventBus() : worker_([this] { run(); }) {}

EventBus::~EventBus() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    stop_ = true;
  }
  cv_.notify_all();
  worker_.join();
}

void EventBus::subscribe(Handler handler) { handlers_.push_back(std::move(handler)); }

void EventBus::publish(Event event) {
  std::lock_guard<std::mutex> lock(mutex_);
  queue_.push_back(std::move(event));
}

void EventBus::run() {
  using namespace std::chrono_literals;
  for (;;) {
    std::unique_lock<std::mutex> lock(mutex_);
    cv_.wait_for(lock, 20ms, [this] { return stop_ || !queue_.empty(); });
    if (stop_) {
      return;
    }
    if (queue_.empty()) {
      continue;
    }
    Event event = std::move(queue_.front());
    queue_.pop_front();
    lock.unlock();
    for (auto & handler : handlers_) {
      handler(event);
    }
  }
}

}  // namespace event_bus
