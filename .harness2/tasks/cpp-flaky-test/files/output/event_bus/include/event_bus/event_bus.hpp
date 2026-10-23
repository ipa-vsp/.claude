#pragma once

#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace event_bus {

struct Event {
  int id{0};
  std::string topic;
};

/// Asynchronous publish/subscribe bus with one dispatch thread.
///
/// Contract:
///  - Handlers run on the dispatch thread, in publish order.
///  - subscribe() and publish() may be called from any thread at any time.
///  - Every event published before the bus is destroyed is delivered to every handler that was
///    subscribed when the event was dispatched; the destructor returns only after that.
class EventBus {
 public:
  using Handler = std::function<void(const Event &)>;

  EventBus();
  ~EventBus();
  EventBus(const EventBus &) = delete;
  EventBus & operator=(const EventBus &) = delete;

  void subscribe(Handler handler);
  void publish(Event event);

 private:
  void run();

  std::vector<Handler> handlers_;
  std::deque<Event> queue_;
  std::mutex mutex_;
  std::condition_variable cv_;
  bool stop_ = false;
  std::thread worker_;
};

}  // namespace event_bus
