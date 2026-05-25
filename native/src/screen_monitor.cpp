#include "screen_monitor.h"

#include "system_utils.h"

#include <chrono>
#include <fcntl.h>
#include <unistd.h>

namespace smart_dimming {
namespace {

constexpr int kScreenPollMs = 3000;
constexpr const char *kWaitForFbWake = "/sys/power/wait_for_fb_wake";

bool WaitForPowerEvent(const char *path) {
    const int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        return false;
    }

    char buffer[16];
    const ssize_t bytes = read(fd, buffer, sizeof(buffer));
    close(fd);
    return bytes >= 0;
}

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

bool ScreenMonitor::WaitForWake(bool &screenOn) {
    if (!initialized_ || currentState_) {
        return false;
    }

    if (!PathExists(kWaitForFbWake) || !WaitForPowerEvent(kWaitForFbWake)) {
        return false;
    }

    const bool newState = IsScreenOn();
    lastPoll_ = std::chrono::steady_clock::now();
    if (!newState) {
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
