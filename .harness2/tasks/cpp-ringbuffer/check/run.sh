#!/usr/bin/env bash
# Hidden acceptance check for cpp-ringbuffer. cwd = workspace; project in output/ringbuffer.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
cd output/ringbuffer || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/ringbuffer missing"}'; exit 1; }
B="$(mktemp -d)"
H=include/ringbuffer/ring_buffer.hpp
ac "cmake configure+build with -Werror" bash -c "cmake -S . -B '$B/own' -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS='-Wall -Wextra -Wpedantic -Werror' && cmake --build '$B/own' -j8"
ac "own ctest passes" bash -c "cd '$B/own' && timeout 300 ctest --output-on-failure"
ac "own tests registered (>= 5)" bash -c "[ \"\$(cd '$B/own' && ctest -N | grep -c 'Test *#')\" -ge 5 ]"
ac "hidden API tests pass" bash -c "g++ -std=c++20 -O1 -Wall -Wextra -Werror -Iinclude '$CHECK/hidden_test.cpp' -lgtest -lgtest_main -pthread -o '$B/hidden' && timeout 300 '$B/hidden'"
ac "hidden tests pass under ThreadSanitizer" bash -c "g++ -std=c++20 -O1 -g -fsanitize=thread -Iinclude '$CHECK/hidden_test.cpp' -lgtest -lgtest_main -pthread -o '$B/hidden_tsan' && TSAN_OPTIONS=halt_on_error=1 timeout 600 '$B/hidden_tsan'"
ac "clang-tidy (bugprone, core guidelines, modernize) clean" bash -c "out=\$(clang-tidy '$CHECK/tidy_tu.cpp' --quiet --header-filter='.*ring_buffer.hpp' --checks='-*,bugprone-*,cppcoreguidelines-*,modernize-*,performance-*,-modernize-use-trailing-return-type,-cppcoreguidelines-avoid-magic-numbers,-bugprone-easily-swappable-parameters,-cppcoreguidelines-pro-bounds-constant-array-index,-cppcoreguidelines-avoid-const-or-ref-data-members,-bugprone-unchecked-optional-access' -- -std=c++20 --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/15 -Iinclude 2>&1); echo \"\$out\"; ! echo \"\$out\" | grep -q 'warning:'"
ac "no raw new/delete" absent '(^|[^_[:alnum:]])(new|delete)[[:space:]]+[A-Za-z_(]' "$H"
rm -rf "$B"
ac_done
