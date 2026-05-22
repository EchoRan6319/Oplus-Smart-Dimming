#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

wait_for_boot

if service_alive; then
    existing_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$existing_pid" ] && [ "$existing_pid" != "$$" ]; then
        log_boot "service already running: pid=$existing_pid, skip duplicate pid=$$"
        exit 0
    fi
fi

echo $$ > "$PID_FILE"
log_boot "service process created: pid=$$ moddir=$MODDIR"

cleanup() {
    rm -f "$PID_FILE"
    log_boot "service stopped"
}

trap 'cleanup; exit 0' INT TERM
trap 'cleanup' EXIT

load_runtime_config() {
    ensure_config_file
    load_selected_packages
    load_debug_config
    GAME_LIST=$(printf '%s\n' "$SELECTED_PACKAGES" | tr '\n' '|' | sed 's/|$//')
    log_debug "config reloaded: selected_count=$(printf '%s\n' "$SELECTED_PACKAGES" | sed '/^$/d' | wc -l | tr -d ' ')"
}

trap 'load_runtime_config' USR1

load_runtime_config

CURRENT_STATE=$(read_current_state)
CURRENT_PACKAGE=""
POLL_INTERVAL="3"
SCREEN_OFF_SLEEP="10"

log_boot "boot completed and shared storage is ready"
log_boot "service initialized: current_state=$CURRENT_STATE poll_interval=${POLL_INTERVAL}s"
log_debug "service started: pid=$$"

while true
do
    if ! is_screen_on; then
        sleep "$SCREEN_OFF_SLEEP"
        continue
    fi

    TARGET_STATE="$DEFAULT_STATE"
    CURRENT_PACKAGE=$(get_top_package)

    if [ -n "$GAME_LIST" ] && package_is_selected "$CURRENT_PACKAGE"; then
        TARGET_STATE="$CLASSIC_STATE"
    fi

    apply_target_state "$TARGET_STATE"
    sleep "$POLL_INTERVAL"
done
