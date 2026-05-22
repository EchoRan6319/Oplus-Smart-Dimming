#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

if [ -f "$PID_FILE" ]; then
    existing_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$existing_pid" ] && [ "$existing_pid" != "$$" ] && [ -d "/proc/$existing_pid" ]; then
        log_boot "service already running: pid=$existing_pid, skip duplicate pid=$$"
        exit 0
    fi
fi

echo $$ > "$PID_FILE"
log_boot "service process created: pid=$$ moddir=$MODDIR"

cleanup() {
    stop_background_helpers
    rm -f "$FIFO_FILE" "$PID_FILE"
    log_boot "service stopped"
}

trap 'cleanup; exit 0' INT TERM
trap 'cleanup' EXIT

wait_for_boot
log_boot "boot completed and shared storage is ready"
ensure_config_file
load_selected_packages
load_debug_config

CURRENT_STATE=$(read_current_state)
CURRENT_PACKAGE=""

rm -f "$FIFO_FILE"
mkfifo "$FIFO_FILE"
log_debug "service started: pid=$$"

handle_reload() {
    load_selected_packages
    load_debug_config
    log_debug "config reloaded: selected_count=$(printf '%s\n' "$SELECTED_PACKAGES" | sed '/^$/d' | wc -l | tr -d ' ')"
    sync_state_from_foreground
}

trap 'handle_reload' USR1

start_logcat_listener() {
    (
        while true; do
            logcat -b events -T 1 -v brief 2>/dev/null \
                | while IFS= read -r line; do
                    case "$line" in
                        *wm_on_top_resumed_gained_called*|*am_focused_activity*)
                            event_pkg=$(extract_event_package "$line")
                            if [ -n "$event_pkg" ]; then
                                printf 'focus:%s\n' "$event_pkg" > "$FIFO_FILE"
                            else
                                printf '%s\n' "focus" > "$FIFO_FILE"
                            fi
                            ;;
                    esac
                done
            sleep 1
        done
    ) &
    echo $! > "$LOGCAT_PID_FILE"
}

start_watchdog() {
    (
        while true; do
            sleep "$WATCHDOG_INTERVAL"
            printf '%s\n' "poll" > "$FIFO_FILE"
        done
    ) &
    echo $! > "$WATCHDOG_PID_FILE"
}

sync_state_from_foreground
start_logcat_listener
start_watchdog

while IFS= read -r event
do
    case "$event" in
        focus:*)
            event_pkg=${event#focus:}
            if [ "$event_pkg" = "$CURRENT_PACKAGE" ]; then
                log_debug "skip duplicate focus event: package=$event_pkg"
                continue
            fi
            if sync_allowed; then
                sync_state_for_package "$event_pkg"
            else
                log_debug "skip throttled focus event: package=$event_pkg"
            fi
            ;;
        focus|poll|reload)
            if sync_allowed; then
                sync_state_from_foreground
            else
                log_debug "skip throttled event: type=$event"
            fi
            ;;
    esac
done < "$FIFO_FILE"
