#include "system_utils.h"

#include <array>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <regex>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

namespace smart_dimming {
namespace {

std::string TimestampNow() {
    using clock = std::chrono::system_clock;
    const auto now = clock::to_time_t(clock::now());
    std::tm tmValue {};
#if defined(_WIN32)
    localtime_s(&tmValue, &now);
#else
    localtime_r(&now, &tmValue);
#endif
    char buffer[32];
    std::strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", &tmValue);
    return buffer;
}

void AppendLine(const std::string &path, const std::string &message) {
    FILE *file = std::fopen(path.c_str(), "ae");
    if (!file) {
        return;
    }
    const auto line = "[" + TimestampNow() + "] " + message + "\n";
    std::fwrite(line.data(), 1, line.size(), file);
    std::fclose(file);
}

bool WriteTextFile(const std::string &path, const std::string &content) {
    FILE *file = std::fopen(path.c_str(), "we");
    if (!file) {
        return false;
    }
    const auto bytes = std::fwrite(content.data(), 1, content.size(), file);
    std::fclose(file);
    return bytes == content.size();
}

bool ReadTextFile(const std::string &path, std::string &content) {
    FILE *file = std::fopen(path.c_str(), "re");
    if (!file) {
        return false;
    }

    content.clear();
    std::array<char, 512> buffer {};
    while (true) {
        const auto read = std::fread(buffer.data(), 1, buffer.size(), file);
        if (read > 0) {
            content.append(buffer.data(), read);
        }
        if (read < buffer.size()) {
            break;
        }
    }

    std::fclose(file);
    return true;
}

std::string ExtractPackageFromLine(const std::string &line) {
    static const std::regex componentRegex(R"(([A-Za-z0-9._$]+)\/[.A-Za-z0-9_$]+)");
    std::smatch match;
    if (std::regex_search(line, match, componentRegex) && match.size() > 1) {
        return match[1].str();
    }
    return {};
}

} // namespace

Paths BuildPaths(const std::string &moduleDir) {
    Paths paths;
    paths.moduleDir = moduleDir;
    paths.configDir = "/storage/emulated/0/Documents/Oplus_Smart_Dimming";
    paths.configFile = paths.configDir + "/packages.conf";
    paths.settingsFile = paths.configDir + "/settings.prop";
    paths.debugLogFile = paths.configDir + "/smart_dimming.log";
    paths.pidFile = "/data/local/tmp/oplus_smart_dimming.pid";
    paths.stateFile = "/data/local/tmp/oplus_smart_dimming.state";
    paths.bootLogFile = "/data/local/tmp/oplus_smart_dimming.boot.log";
    return paths;
}

bool EnsureDirectory(const std::string &path) {
    if (path.empty()) {
        return false;
    }

    struct stat st {};
    if (stat(path.c_str(), &st) == 0) {
        return true;
    }

    std::size_t pos = 0;
    while (true) {
        pos = path.find('/', pos + 1);
        const auto sub = pos == std::string::npos ? path : path.substr(0, pos);
        if (sub.empty()) {
            if (pos == std::string::npos) {
                break;
            }
            continue;
        }
        mkdir(sub.c_str(), 0775);
        if (pos == std::string::npos) {
            break;
        }
    }

    return stat(path.c_str(), &st) == 0;
}

bool PathExists(const std::string &path) {
    return access(path.c_str(), F_OK) == 0;
}

bool EnsureConfigFile(const Paths &paths) {
    EnsureDirectory(paths.configDir);

    if (!PathExists(paths.settingsFile)) {
        WriteTextFile(paths.settingsFile, "# 欧加真智能调光 - WebUI 设置\ndebug_logging=0\n");
    }

    if (PathExists(paths.configFile)) {
        return true;
    }

    return WriteTextFile(paths.configFile,
                         "# ===================================================\n"
                         "# 欧加真智能调光 - 应用名单\n"
                         "# ===================================================\n"
                         "# 每行一个包名，进入这些应用时切换到【经典低频闪】。\n"
                         "# ===================================================\n"
                         "com.tencent.tmgp.sgame\n"
                         "com.tencent.tmgp.pubgmhd\n"
                         "com.miHoYo.Yuanshen\n"
                         "com.miHoYo.hkrpg\n");
}

void AppendBootLog(const Paths &paths, const std::string &message) {
    AppendLine(paths.bootLogFile, message);
}

bool DebugLoggingEnabled(const Paths &paths) {
    std::string content;
    if (!ReadTextFile(paths.settingsFile, content)) {
        return false;
    }

    std::istringstream stream(content);
    std::string line;
    while (std::getline(stream, line)) {
        line = Trim(line);
        if (line.rfind("debug_logging=", 0) == 0) {
            const auto value = Trim(line.substr(std::string("debug_logging=").size()));
            return value == "1" || value == "on" || value == "true" || value == "enabled";
        }
    }
    return false;
}

void AppendDebugLog(const Paths &paths, const std::string &message) {
    if (!DebugLoggingEnabled(paths)) {
        return;
    }
    AppendLine(paths.debugLogFile, message);
}

bool WritePidFile(const std::string &path, int pid) {
    return WriteTextFile(path, std::to_string(pid) + "\n");
}

void RemoveFileIfExists(const std::string &path) {
    unlink(path.c_str());
}

std::string ExecCommand(const std::string &command) {
    std::array<char, 512> buffer {};
    std::string output;
    FILE *pipe = popen(command.c_str(), "r");
    if (!pipe) {
        return output;
    }
    while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
        output += buffer.data();
    }
    pclose(pipe);
    return output;
}

std::string Trim(const std::string &value) {
    const auto first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) {
        return {};
    }
    const auto last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

bool IsScreenOn() {
    const auto dump = ExecCommand("/system/bin/dumpsys power 2>/dev/null");
    if (dump.find("mWakefulness=Awake") != std::string::npos) {
        return true;
    }
    if (dump.find("Display Power: state=ON") != std::string::npos) {
        return true;
    }
    return false;
}

std::string ResolveTopPackage() {
    const auto windowDump = ExecCommand("/system/bin/dumpsys window 2>/dev/null");
    {
        std::istringstream stream(windowDump);
        std::string line;
        while (std::getline(stream, line)) {
            if (line.find("mCurrentFocus") != std::string::npos ||
                line.find("mFocusedApp") != std::string::npos) {
                const auto pkg = ExtractPackageFromLine(line);
                if (!pkg.empty()) {
                    return pkg;
                }
            }
        }
    }

    const auto activityDump = ExecCommand("/system/bin/dumpsys activity activities 2>/dev/null");
    {
        std::istringstream stream(activityDump);
        std::string line;
        while (std::getline(stream, line)) {
            if (line.find("mResumedActivity") != std::string::npos ||
                line.find("topResumedActivity") != std::string::npos) {
                const auto pkg = ExtractPackageFromLine(line);
                if (!pkg.empty()) {
                    return pkg;
                }
            }
        }
    }

    const auto lruDump = ExecCommand("/system/bin/dumpsys activity lru 2>/dev/null");
    {
        std::istringstream stream(lruDump);
        std::string line;
        while (std::getline(stream, line)) {
            if (line.find(" TOP") != std::string::npos || line.find("(top-activity)") != std::string::npos) {
                const auto pkg = ExtractPackageFromLine(line);
                if (!pkg.empty()) {
                    return pkg;
                }
            }
        }
    }

    return {};
}

int ReadCurrentSettingState() {
    const auto value = Trim(ExecCommand(std::string("/system/bin/settings get secure ") + kSettingKey + " 2>/dev/null"));
    if (value == "0" || value == "1" || value == "2") {
        return std::atoi(value.c_str());
    }
    return -1;
}

bool WriteCurrentSettingState(int state) {
    const std::string command = std::string("/system/bin/settings put secure ") + kSettingKey + " " +
                                std::to_string(state) + " >/dev/null 2>&1";
    return std::system(command.c_str()) == 0;
}

bool WriteStateFile(const Paths &paths, const RuntimeStateSnapshot &snapshot) {
    std::string content;
    content += "current_state=" + std::to_string(snapshot.currentState) + "\n";
    content += "top_package=" + snapshot.currentPackage + "\n";
    content += "selected_count=" + std::to_string(snapshot.selectedCount) + "\n";
    content += "runtime_mode=" + snapshot.runtimeMode + "\n";
    content += "screen_on=" + std::string(snapshot.screenOn ? "1" : "0") + "\n";
    content += "app_monitor=" + snapshot.appMonitorSummary + "\n";
    content += "note=" + snapshot.note + "\n";
    content += "last_update=" + TimestampNow() + "\n";
    return WriteTextFile(paths.stateFile, content);
}

std::unordered_set<std::string> LoadSelectedPackages(const std::string &configFile) {
    std::unordered_set<std::string> packages;
    std::string content;
    if (!ReadTextFile(configFile, content)) {
        return packages;
    }

    static const std::regex packageRegex(R"(^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$)");
    std::istringstream stream(content);
    std::string line;
    while (std::getline(stream, line)) {
        line = Trim(line);
        if (line.empty() || line[0] == '#') {
            continue;
        }
        const auto commentPos = line.find('#');
        if (commentPos != std::string::npos) {
            line = Trim(line.substr(0, commentPos));
        }
        if (!line.empty() && std::regex_match(line, packageRegex)) {
            packages.insert(line);
        }
    }
    return packages;
}

} // namespace smart_dimming
