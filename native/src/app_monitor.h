#pragma once

#include <chrono>
#include <string>
#include <vector>

namespace smart_dimming {

struct AppMonitorStatus {
    bool eventDriven = false;
    bool fallbackArmed = true;
    bool fallbackForced = false;
    int watchCount = 0;
    int inotifyEvents = 0;
    int fallbackPolls = 0;
    int resolveAttempts = 0;
    int resolveFailures = 0;
    int repeatedPackages = 0;
    int consecutiveResolveFailures = 0;
    std::string lastResolvedPackage;
    std::string lastResolveSource;
    std::string lastFailureReason;
    std::string watchedPaths;
};

class AppMonitor {
public:
    AppMonitor();
    ~AppMonitor();

    bool Start(std::string &diagnostic);
    bool EventDriven() const;
    bool WaitForPackageChange(std::string &packageName, std::string &runtimeMode, bool screenOn);
    std::string DebugSummary() const;
    const AppMonitorStatus &Status() const;

private:
    void RegisterWatch(const std::string &path);
    bool ResolvePackage(std::string &packageName, const std::string &source);
    bool PollInotify(std::string &packageName);
    bool PollFallback(std::string &packageName);
    int64_t CurrentFallbackIntervalMs() const;
    bool ShouldAllowFallbackPoll(int64_t elapsedMs, bool screenOn) const;

    int inotifyFd_;
    std::vector<int> watchDescriptors_;
    std::vector<std::string> watchedPaths_;
    std::chrono::steady_clock::time_point lastFallbackPoll_;
    std::chrono::steady_clock::time_point lastEventActivity_;
    std::string lastResolvedPackage_;
    AppMonitorStatus status_;
};

} // namespace smart_dimming
