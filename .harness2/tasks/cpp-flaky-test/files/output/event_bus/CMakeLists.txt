cmake_minimum_required(VERSION 3.20)
project(event_bus LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Threads REQUIRED)
add_library(event_bus src/event_bus.cpp)
target_include_directories(event_bus PUBLIC include)
target_link_libraries(event_bus PUBLIC Threads::Threads)

enable_testing()
find_package(GTest REQUIRED)
add_executable(test_event_bus tests/test_event_bus.cpp)
target_link_libraries(test_event_bus PRIVATE event_bus GTest::gtest_main)
include(GoogleTest)
gtest_discover_tests(test_event_bus)
