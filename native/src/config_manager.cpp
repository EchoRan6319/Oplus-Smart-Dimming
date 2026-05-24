#include "config_manager.h"

namespace smart_dimming {

ConfigManager::ConfigManager(Paths paths) : paths_(std::move(paths)) {}

bool ConfigManager::Load() {
    if (!EnsureConfigFile(paths_)) {
        return false;
    }
    selectedPackages_ = LoadSelectedPackages(paths_.configFile);
    return true;
}

const std::unordered_set<std::string> &ConfigManager::SelectedPackages() const {
    return selectedPackages_;
}

const Paths &ConfigManager::GetPaths() const {
    return paths_;
}

} // namespace smart_dimming
