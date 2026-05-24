#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

ensure_config_file
load_selected_packages
load_debug_config

current_state=$(settings get secure "$SETTING_KEY" 2>/dev/null)
service_status="stopped"

if service_alive; then
    service_status="running"
fi

printf 'service=%s\n' "$service_status"
printf 'state=%s\n' "$current_state"
printf 'count=%s\n' "$(printf '%s\n' "$SELECTED_PACKAGES" | sed '/^$/d' | wc -l | tr -d ' ')"
printf 'config=%s\n' "$CONFIG_FILE"
printf 'debug=%s\n' "$DEBUG_LOG_ENABLED"
printf 'log=%s\n' "$DEBUG_LOG_FILE"

if [ -f "$STATE_FILE" ]; then
    grep -E '^(top_package|runtime_mode|screen_on|app_monitor|note|last_update)=' "$STATE_FILE" 2>/dev/null
fi
