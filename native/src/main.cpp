#include "app_monitor.h"
#include "config_manager.h"
#include "screen_monitor.h"
#include "state_controller.h"
#include "system_utils.h"

#include <csignal>
#include <chrono>
#include <cstring>
#include <string>
#include <thread>

#include <signal.h>
#include <sys/types.h>
#include <unistd.h>

namespace smart_dimming {
namespace {

volatile std::sig_atomic_t gShouldStop = 0;
volatile std::sig_atomic_t gShouldReload = 0;
constexpr int kScreenOnIdleSleepMs = 200;
constexpr int kScreenOffIdleSleepMs = 5000;

void HandleSignal(int signal) {
    if (signal == SIGUSR1) {
        gShouldReload = 1;
        return;
    }
    gShouldStop = 1;
}

void RegisterSignals() {
    struct sigaction action {};
    action.sa_handler = HandleSignal;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;

    sigaction(SIGINT, &action, nullptr);
    sigaction(SIGTERM, &action, nullptr);
    sigaction(SIGUSR1, &action, nullptr);
}

std::string ParseModuleDir(int argc, char **argv) {
    for (int i = 1; i < argc - 1; ++i) {
        if (std::strcmp(argv[i], "--module-dir") == 0) {
            return argv[i + 1];
        }
    }
    return {};
}

} // namespace
} // namespace smart_dimming

int main(int argc, char **argv) {
    using namespace smart_dimming;

    const auto moduleDir = ParseModuleDir(argc, argv);
    if (moduleDir.empty()) {
        return 1;
    }

    const auto paths = BuildPaths(moduleDir);
    EnsureConfigFile(paths);
    AppendBootLog(paths, "native daemon starting");

    RegisterSignals();

    if (!WritePidFile(paths.pidFile, static_cast<int>(getpid()))) {
        AppendBootLog(paths, "failed to write pid file");
    }

    ConfigManager config(paths);
    if (!config.Load()) {
        AppendBootLog(paths, "failed to load config");
        RemoveFileIfExists(paths.pidFile);
        return 1;
    }

    StateController controller(config);
    controller.RefreshCurrentState();

    AppMonitor monitor;
    std::string appMonitorDiagnostic;
    const bool eventMode = monitor.Start(appMonitorDiagnostic);
    AppendBootLog(paths, std::string(eventMode ? "app monitor started in event mode: "
                                               : "app monitor started without event watches: ") +
                               appMonitorDiagnostic);

    ScreenMonitor screenMonitor;
    bool screenOn = true;
    if (screenMonitor.PollStateChange(screenOn)) {
        controller.SetScreenState(screenOn);
        AppendBootLog(paths, std::string("screen state initialized: ") + (screenOn ? "on" : "off"));
    }

    const auto initialPackage = ResolveTopPackage();
    controller.ApplyPackageChange(initialPackage, eventMode ? "event" : "fallback_poll");
    controller.PublishState(eventMode ? "event" : "fallback_poll", monitor.DebugSummary(), "startup");

    while (!gShouldStop) {
        if (gShouldReload) {
            gShouldReload = 0;
            if (config.Load()) {
                const auto reloadedPackage = screenOn ? ResolveTopPackage() : std::string {};
                controller.ApplyPackageChange(reloadedPackage, eventMode ? "event_reload" : "fallback_reload");
                controller.PublishState(eventMode ? "event_reload" : "fallback_reload", monitor.DebugSummary(),
                                        "config reloaded");
                AppendBootLog(paths, "config reloaded");
            } else {
                controller.PublishState(eventMode ? "event_reload" : "fallback_reload", monitor.DebugSummary(),
                                        "config reload failed");
                AppendBootLog(paths, "config reload failed");
            }
        }

        bool newScreenOn = screenOn;
        if (screenMonitor.PollStateChange(newScreenOn)) {
            screenOn = newScreenOn;
            controller.SetScreenState(screenOn);
            AppendBootLog(paths, std::string("screen state changed: ") + (screenOn ? "on" : "off"));

            if (screenOn) {
                controller.ApplyPackageChange(ResolveTopPackage(), eventMode ? "event" : "fallback_poll");
                controller.PublishState(eventMode ? "event" : "fallback_poll", monitor.DebugSummary(),
                                        "screen on refresh");
            } else {
                controller.ApplyPackageChange({}, "screen_off");
                controller.PublishState("screen_off", monitor.DebugSummary(), "screen off fallback default");
            }
        }

        std::string packageName;
        std::string runtimeMode;
        if (!monitor.WaitForPackageChange(packageName, runtimeMode, screenOn)) {
            if (!screenOn) {
                bool wakeScreenOn = false;
                if (screenMonitor.WaitForWake(wakeScreenOn)) {
                    screenOn = wakeScreenOn;
                    controller.SetScreenState(screenOn);
                    AppendBootLog(paths, "screen state changed: on");
                    controller.ApplyPackageChange(ResolveTopPackage(), eventMode ? "event" : "fallback_poll");
                    controller.PublishState(eventMode ? "event" : "fallback_poll", monitor.DebugSummary(),
                                            "screen on refresh");
                    continue;
                }
                if (gShouldStop || gShouldReload) {
                    continue;
                }
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(screenOn ? kScreenOnIdleSleepMs
                                                                            : kScreenOffIdleSleepMs));
            continue;
        }

        AppendDebugLog(paths, "app event: mode=" + runtimeMode + " package=" + packageName + " " +
                                  monitor.DebugSummary());
        controller.ApplyPackageChange(packageName, runtimeMode);
        controller.PublishState(runtimeMode, monitor.DebugSummary(), "package change");
    }

    AppendBootLog(paths, "native daemon stopping");
    RemoveFileIfExists(paths.pidFile);
    return 0;
}
