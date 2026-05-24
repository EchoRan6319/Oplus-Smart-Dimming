#include "screen_monitor.h"

#include "system_utils.h"

#include <chrono>

namespace smart_dimming {
namespace {

constexpr int kScreenPollMs = 3000;

} // namespace

ScreenMonitor::ScreenMonitor()
    : initialized_(false), currentState_(true), lastPoll_(std::chrono::steady_clock::now()) {}

bool ScreenMonitor::PollStateChange(bool &screenOn) {
    const auto now = std::chrono::steady_clock::now();
    const auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastPoll_).count();
    if (initialized_ && elapsedMs < kScreenPollMs) {
        return false;
    }

    lastPoll_ = now;
    const bool newState = IsScreenOn();
    if (!initialized_) {
        initialized_ = true;
        currentState_ = newState;
        screenOn = currentState_;
        return true;
    }

    if (newState == currentState_) {
        return false;
    }

    currentState_ = newState;
    screenOn = currentState_;
    return true;
}

bool ScreenMonitor::CurrentState() const {
    return currentState_;
}

} // namespace smart_dimming
