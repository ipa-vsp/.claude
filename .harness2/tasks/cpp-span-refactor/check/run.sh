#!/usr/bin/env bash
# Hidden acceptance check for cpp-span-refactor. cwd = workspace; project in output/signal_utils.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
cd output/signal_utils || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/signal_utils missing"}'; exit 1; }
B="$(mktemp -d)"
ac "cmake build with -Wconversion -Werror" bash -c "cmake -S . -B '$B/own' -DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Wconversion -Werror' && cmake --build '$B/own' -j8"
ac "own ctest passes" bash -c "cd '$B/own' && timeout 300 ctest --output-on-failure"
ac "own tests extended (>= 6)" bash -c "[ \"\$(cd '$B/own' && ctest -N | grep -c 'Test *#')\" -ge 6 ]"
ac "hidden span API tests pass" bash -c "g++ -std=c++20 -Wall -Wextra -Werror -Iinclude src/*.cpp '$CHECK/hidden_test.cpp' -lgtest -lgtest_main -pthread -o '$B/hidden' && '$B/hidden'"
ac "no pointer+length parameters left in header" absent '(const )?(double|int) ?\* ?[a-z_]+, ?std::size_t' include/signal_utils/signal_utils.hpp
ac "pure functions are [[nodiscard]]" bash -c "[ \"\$(grep -c 'nodiscard' include/signal_utils/signal_utils.hpp)\" -ge 3 ]"
rm -rf "$B"
ac_done
