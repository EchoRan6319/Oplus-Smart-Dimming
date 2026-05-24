#pragma once

#include <string>
#include <unordered_set>

namespace smart_dimming {

struct Paths {
    std::string moduleDir;
    std::string configDir;
    std::string configFile;
    std::string settingsFile;
    std::string debugLogFile;
    std::string pidFile;
    std::string stateFile;
    std::string bootLogFile;
};

struct RuntimeStateSnapshot {
    int currentState = -1;
    std::string currentPackage;
    std::size_t selectedCount = 0;
    std::string runtimeMode;
    bool screenOn = true;
    std::string appMonitorSummary;
    std::string note;
};

constexpr const char *kSettingKey = "display_single_pulse_eyeprotection_switch";
constexpr int kDefaultState = 2;
constexpr int kClassicState = 0;

Paths BuildPaths(const std::string &moduleDir);
bool EnsureDirectory(const std::string &path);
bool EnsureConfigFile(const Paths &paths);
void AppendBootLog(const Paths &paths, const std::string &message);
void AppendDebugLog(const Paths &paths, const std::string &message);
bool DebugLoggingEnabled(const Paths &paths);
bool WritePidFile(const std::string &path, int pid);
void RemoveFileIfExists(const std::string &path);
std::string ExecCommand(const std::string &command);
std::string Trim(const std::string &value);
bool IsScreenOn();
bool PathExists(const std::string &path);
std::string ResolveTopPackage();
int ReadCurrentSettingState();
bool WriteCurrentSettingState(int state);
bool WriteStateFile(const Paths &paths, const RuntimeStateSnapshot &snapshot);
std::unordered_set<std::string> LoadSelectedPackages(const std::string &configFile);

} // namespace smart_dimming
