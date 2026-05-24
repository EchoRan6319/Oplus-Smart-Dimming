#include "app_monitor.h"

#include "system_utils.h"

#include <poll.h>
#include <sys/inotify.h>
#include <sys/types.h>
#include <unistd.h>

#include <array>
#include <cstring>

namespace smart_dimming {
namespace {

constexpr int kDebounceMs = 800;
constexpr int kResolveRetryDelayMs = 300;
constexpr int kResolveRetryCount = 2;
constexpr int kForcedFallbackPollMs = 15000;
constexpr int kFallbackPollMs = 60000;
constexpr int kStableFallbackPollMs = 180000;
constexpr int kFallbackIdleThresholdMs = 45000;
constexpr int kStableEventThreshold = 10;
constexpr const char *kTopAppTasks = "/dev/cpuset/top-app/tasks";
constexpr const char *kTopAppProcs = "/dev/cpuset/top-app/cgroup.procs";
constexpr const char *kForegroundTasks = "/dev/cpuset/foreground/tasks";
constexpr const char *kForegroundProcs = "/dev/cpuset/foreground/cgroup.procs";

} // namespace

AppMonitor::AppMonitor()
    : inotifyFd_(-1),
      lastFallbackPoll_(std::chrono::steady_clock::now()),
      lastEventActivity_(std::chrono::steady_clock::now()) {}

AppMonitor::~AppMonitor() {
    if (inotifyFd_ >= 0) {
        close(inotifyFd_);
    }
}

bool AppMonitor::Start(std::string &diagnostic) {
    inotifyFd_ = inotify_init1(IN_CLOEXEC);
    if (inotifyFd_ < 0) {
        status_.eventDriven = false;
        status_.fallbackForced = true;
        status_.lastFailureReason = "inotify init failed";
        diagnostic = "inotify init failed";
        return false;
    }

    RegisterWatch(kTopAppTasks);
    RegisterWatch(kTopAppProcs);
    RegisterWatch(kForegroundTasks);
    RegisterWatch(kForegroundProcs);
    status_.eventDriven = !watchDescriptors_.empty();
    status_.watchCount = static_cast<int>(watchDescriptors_.size());
    status_.fallbackForced = !status_.eventDriven;
    if (!status_.eventDriven) {
        status_.lastFailureReason = "no cpuset watch path available";
    }
    diagnostic = DebugSummary();
    return status_.eventDriven;
}

bool AppMonitor::EventDriven() const {
    return status_.eventDriven;
}

void AppMonitor::RegisterWatch(const std::string &path) {
    if (!PathExists(path)) {
        return;
    }
    const int wd = inotify_add_watch(inotifyFd_, path.c_str(), IN_MODIFY);
    if (wd >= 0) {
        watchDescriptors_.push_back(wd);
        watchedPaths_.push_back(path);
        if (!status_.watchedPaths.empty()) {
            status_.watchedPaths += ", ";
        }
        status_.watchedPaths += path;
    }
}

bool AppMonitor::WaitForPackageChange(std::string &packageName, std::string &runtimeMode, bool screenOn) {
    if (screenOn && status_.eventDriven && PollInotify(packageName)) {
        runtimeMode = "event";
        return true;
    }
    if (screenOn && PollFallback(packageName)) {
        runtimeMode = status_.eventDriven ? "event_fallback" : "fallback_poll";
        return true;
    }
    return false;
}

std::string AppMonitor::DebugSummary() const {
    std::string summary = "event=";
    summary += status_.eventDriven ? "1" : "0";
    summary += " fallback_forced=";
    summary += status_.fallbackForced ? "1" : "0";
    summary += " watches=" + std::to_string(status_.watchCount);
    summary += " inotify_events=" + std::to_string(status_.inotifyEvents);
    summary += " fallback_polls=" + std::to_string(status_.fallbackPolls);
    summary += " resolve_attempts=" + std::to_string(status_.resolveAttempts);
    summary += " resolve_failures=" + std::to_string(status_.resolveFailures);
    summary += " repeated=" + std::to_string(status_.repeatedPackages);
    if (!status_.lastResolveSource.empty()) {
        summary += " last_source=" + status_.lastResolveSource;
    }
    if (!status_.lastResolvedPackage.empty()) {
        summary += " last_pkg=" + status_.lastResolvedPackage;
    }
    if (!status_.lastFailureReason.empty()) {
        summary += " last_failure=\"" + status_.lastFailureReason + "\"";
    }
    if (!status_.watchedPaths.empty()) {
        summary += " watched=[" + status_.watchedPaths + "]";
    }
    return summary;
}

const AppMonitorStatus &AppMonitor::Status() const {
    return status_;
}

bool AppMonitor::ResolvePackage(std::string &packageName, const std::string &source) {
    ++status_.resolveAttempts;

    packageName = ResolveTopPackage();
    for (int retry = 0; packageName.empty() && retry < kResolveRetryCount; ++retry) {
        usleep(kResolveRetryDelayMs * 1000);
        packageName = ResolveTopPackage();
    }

    if (packageName.empty()) {
        ++status_.resolveFailures;
        ++status_.consecutiveResolveFailures;
        status_.lastFailureReason = "package resolve returned empty after retry";
        if (!lastResolvedPackage_.empty()) {
            packageName = lastResolvedPackage_;
            status_.lastFailureReason += ", retained previous package";
        }
        if (status_.consecutiveResolveFailures >= 3) {
            status_.fallbackForced = true;
        }
        return false;
    }

    status_.consecutiveResolveFailures = 0;
    status_.lastResolvedPackage = packageName;
    status_.lastResolveSource = source;
    if (packageName == lastResolvedPackage_) {
        ++status_.repeatedPackages;
        status_.lastFailureReason = "resolved package unchanged";
        return false;
    }

    lastResolvedPackage_ = packageName;
    lastEventActivity_ = std::chrono::steady_clock::now();
    status_.fallbackForced = false;
    status_.lastFailureReason.clear();
    return true;
}

bool AppMonitor::PollInotify(std::string &packageName) {
    pollfd pfd {};
    pfd.fd = inotifyFd_;
    pfd.events = POLLIN;

    const int result = poll(&pfd, 1, 1000);
    if (result <= 0 || (pfd.revents & POLLIN) == 0) {
        return false;
    }

    std::array<char, 1024> buffer {};
    const auto bytes = read(inotifyFd_, buffer.data(), buffer.size());
    if (bytes <= 0) {
        return false;
    }

    ++status_.inotifyEvents;
    usleep(kDebounceMs * 1000);
    return ResolvePackage(packageName, "inotify");
}

bool AppMonitor::PollFallback(std::string &packageName) {
    const auto now = std::chrono::steady_clock::now();
    const auto elapsedMs =
        std::chrono::duration_cast<std::chrono::milliseconds>(now - lastFallbackPoll_).count();
    if (!ShouldAllowFallbackPoll(elapsedMs, true)) {
        return false;
    }
    lastFallbackPoll_ = now;
    ++status_.fallbackPolls;

    if (!IsScreenOn()) {
        status_.lastFailureReason = "fallback skipped while screen off";
        return false;
    }

    return ResolvePackage(packageName, status_.fallbackForced ? "forced_fallback" : "fallback_poll");
}

int64_t AppMonitor::CurrentFallbackIntervalMs() const {
    if (status_.fallbackForced) {
        return kForcedFallbackPollMs;
    }
    if (status_.eventDriven && status_.inotifyEvents >= kStableEventThreshold && status_.resolveFailures == 0) {
        return kStableFallbackPollMs;
    }
    return kFallbackPollMs;
}

bool AppMonitor::ShouldAllowFallbackPoll(int64_t elapsedMs, bool screenOn) const {
    if (!screenOn) {
        return false;
    }

    const auto sinceLastEventMs =
        std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - lastEventActivity_)
            .count();

    if (status_.fallbackForced) {
        return elapsedMs >= CurrentFallbackIntervalMs();
    }

    if (status_.eventDriven && sinceLastEventMs < kFallbackIdleThresholdMs) {
        return false;
    }

    return elapsedMs >= CurrentFallbackIntervalMs();
}
} // namespace smart_dimming
