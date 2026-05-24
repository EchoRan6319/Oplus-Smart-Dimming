#pragma once

#include "system_utils.h"

#include <string>
#include <unordered_set>

namespace smart_dimming {

class ConfigManager {
public:
    explicit ConfigManager(Paths paths);

    bool Load();
    const std::unordered_set<std::string> &SelectedPackages() const;
    const Paths &GetPaths() const;

private:
    Paths paths_;
    std::unordered_set<std::string> selectedPackages_;
};

} // namespace smart_dimming
