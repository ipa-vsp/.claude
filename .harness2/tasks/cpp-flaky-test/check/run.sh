#!/usr/bin/env bash
# Hidden acceptance check for cpp-flaky-test. cwd = workspace; project in output/event_bus.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
cd output/event_bus || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/event_bus missing"}'; exit 1; }
B="$(mktemp -d)"
SRCS="$(ls src/*.cpp)"
ac "cmake build with -Werror" bash -c "cmake -S . -B '$B/own' -DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror' && cmake --build '$B/own' -j8"
ac "own tests pass 50x (ctest --repeat until-fail:50)" bash -c "cd '$B/own' && timeout 600 ctest --repeat until-fail:50 --output-on-failure -j4"
ac "own tests added (>= 4)" bash -c "[ \"\$(cd '$B/own' && ctest -N | grep -c 'Test *#')\" -ge 4 ]"
ac "no sleeps in tests" absent 'sleep_for|sleep_until|usleep|[^_]sleep\(' tests
ac "hidden contract tests pass" bash -c "g++ -std=c++20 -O1 -Iinclude $SRCS '$CHECK/hidden_test.cpp' -lgtest -lgtest_main -pthread -o '$B/hidden' && timeout 300 '$B/hidden' --gtest_repeat=5"
ac "hidden tests clean under ThreadSanitizer" bash -c "g++ -std=c++20 -O1 -g -fsanitize=thread -Iinclude $SRCS '$CHECK/hidden_test.cpp' -lgtest -lgtest_main -pthread -o '$B/tsan' && TSAN_OPTIONS=halt_on_error=1 timeout 600 '$B/tsan'"
rm -rf "$B"
ac_done
