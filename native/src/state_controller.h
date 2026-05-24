#pragma once

#include "config_manager.h"

#include <string>

namespace smart_dimming {

class StateController {
public:
    explicit StateController(ConfigManager &configManager);

    void RefreshCurrentState();
    void ReloadConfig();
    void SetScreenState(bool screenOn);
    bool ApplyPackageChange(const std::string &packageName, const std::string &runtimeMode);
    bool PublishState(const std::string &runtimeMode,
                      const std::string &appMonitorSummary = {},
                      const std::string &note = {});

private:
    int ComputeTargetState(const std::string &packageName) const;

    ConfigManager &configManager_;
    int appliedState_;
    std::string currentPackage_;
    std::string lastPublishedMode_;
    bool screenOn_;
};

} // namespace smart_dimming
