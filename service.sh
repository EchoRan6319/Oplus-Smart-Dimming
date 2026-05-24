#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

# Some installers drop executable bits from module files.
# Repair them at service start so the native daemon can self-heal after install/update.
chmod 0755 "$MODDIR/service.sh" "$MODDIR/action.sh" 2>/dev/null
chmod 0755 "$MODDIR/bin/oplus_smart_dimmingd" 2>/dev/null
chmod 0755 "$MODDIR"/scripts/*.sh 2>/dev/null

wait_for_boot

if service_alive; then
    existing_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$existing_pid" ] && [ "$existing_pid" != "$$" ]; then
        log_boot "service already running: pid=$existing_pid, skip duplicate launcher pid=$$"
        exit 0
    fi
fi

log_boot "boot completed and shared storage is ready"
log_boot "service launcher started: pid=$$ moddir=$MODDIR"

if [ -x "$DAEMON_BIN" ]; then
    log_boot "starting native daemon: $DAEMON_BIN"
    exec "$DAEMON_BIN" --module-dir "$MODDIR"
fi

log_boot "native daemon missing, using legacy shell fallback"
exec sh "$MODDIR/scripts/legacy_loop.sh"
