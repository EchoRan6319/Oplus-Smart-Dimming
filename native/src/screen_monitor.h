#pragma once

#include <chrono>

namespace smart_dimming {

class ScreenMonitor {
public:
    ScreenMonitor();

    bool PollStateChange(bool &screenOn);
    bool WaitForWake(bool &screenOn);
    bool CurrentState() const;

private:
    bool initialized_;
    bool currentState_;
    std::chrono::steady_clock::time_point lastPoll_;
};

} // namespace smart_dimming
