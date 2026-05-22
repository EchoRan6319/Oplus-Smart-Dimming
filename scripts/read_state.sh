#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

ensure_config_file
load_selected_packages
load_debug_config
load_refresh_interval

current_state=$(settings get secure "$SETTING_KEY" 2>/dev/null)
top_package=$(get_top_package)
service_status="stopped"

if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
        service_status="running"
    fi
fi

printf 'service=%s\n' "$service_status"
printf 'state=%s\n' "$current_state"
printf 'top=%s\n' "$top_package"
printf 'count=%s\n' "$(printf '%s\n' "$SELECTED_PACKAGES" | sed '/^$/d' | wc -l | tr -d ' ')"
printf 'config=%s\n' "$CONFIG_FILE"
printf 'debug=%s\n' "$DEBUG_LOG_ENABLED"
printf 'log=%s\n' "$DEBUG_LOG_FILE"
printf 'refresh=%s\n' "$WEBUI_REFRESH_INTERVAL"
