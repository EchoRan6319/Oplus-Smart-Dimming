cmake_minimum_required(VERSION 3.16)
project(oplus_smart_dimmingd LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(oplus_smart_dimmingd
    src/app_monitor.cpp
    src/config_manager.cpp
    src/main.cpp
    src/screen_monitor.cpp
    src/state_controller.cpp
    src/system_utils.cpp
)

target_include_directories(oplus_smart_dimmingd PRIVATE src)
target_link_options(oplus_smart_dimmingd PRIVATE -static-libstdc++)
