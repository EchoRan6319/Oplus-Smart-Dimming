#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

echo $$ > "$PID_FILE"
log_boot "service process created: pid=$$ moddir=$MODDIR"

cleanup() {
    stop_background_helpers
    rm -f "$FIFO_FILE" "$PID_FILE"
    log_boot "service stopped"
}

trap 'cleanup; exit 0' INT TERM EXIT

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
    if [ -p "$FIFO_FILE" ]; then
        printf '%s\n' "reload" > "$FIFO_FILE"
    fi
}

trap 'handle_reload' USR1

start_logcat_listener() {
    (
        while true; do
            logcat -b events -T 1 -v brief 2>/dev/null \
                | while IFS= read -r line; do
                    case "$line" in
                        *wm_on_resume_called*|*am_on_resume_called*|*wm_on_top_resumed_gained_called*|*am_focused_activity*|*wm_task_moved*|*wm_task_to_front*)
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
            sync_state_for_package "${event#focus:}"
            ;;
        focus|poll|reload)
            sync_state_from_foreground
            ;;
    esac
done < "$FIFO_FILE"
