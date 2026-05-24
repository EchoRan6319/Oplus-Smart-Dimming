#include "state_controller.h"

#include "system_utils.h"

namespace smart_dimming {

StateController::StateController(ConfigManager &configManager)
    : configManager_(configManager), appliedState_(ReadCurrentSettingState()), screenOn_(true) {}

void StateController::RefreshCurrentState() {
    appliedState_ = ReadCurrentSettingState();
}

void StateController::ReloadConfig() {
    configManager_.Load();
}

void StateController::SetScreenState(bool screenOn) {
    screenOn_ = screenOn;
}

int StateController::ComputeTargetState(const std::string &packageName) const {
    if (!screenOn_) {
        return kDefaultState;
    }
    if (!packageName.empty() && configManager_.SelectedPackages().count(packageName) > 0) {
        return kClassicState;
    }
    return kDefaultState;
}

bool StateController::ApplyPackageChange(const std::string &packageName, const std::string &runtimeMode) {
    currentPackage_ = packageName;
    const auto targetState = ComputeTargetState(packageName);
    if (appliedState_ != targetState) {
        if (!WriteCurrentSettingState(targetState)) {
            AppendBootLog(configManager_.GetPaths(),
                          "settings write failed: package=" + packageName + " target=" + std::to_string(targetState));
            return false;
        }
        appliedState_ = targetState;
        AppendDebugLog(configManager_.GetPaths(),
                       "switch state: package=" + packageName + " target=" + std::to_string(targetState));
    }
    return PublishState(runtimeMode);
}

bool StateController::PublishState(const std::string &runtimeMode,
                                   const std::string &appMonitorSummary,
                                   const std::string &note) {
    RuntimeStateSnapshot snapshot;
    snapshot.currentState = appliedState_;
    snapshot.currentPackage = currentPackage_;
    snapshot.selectedCount = configManager_.SelectedPackages().size();
    snapshot.runtimeMode = runtimeMode;
    snapshot.screenOn = screenOn_;
    snapshot.appMonitorSummary = appMonitorSummary;
    snapshot.note = note;
    lastPublishedMode_ = runtimeMode;
    return WriteStateFile(configManager_.GetPaths(), snapshot);
}

} // namespace smart_dimming
