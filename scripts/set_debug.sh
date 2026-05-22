#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

load_debug_config
load_refresh_interval
set_debug_logging "$1"

if ensure_service_running; then
    if reload_running_service; then
        echo "OK: debug logging set to $DEBUG_LOG_ENABLED and service reloaded"
    else
        echo "OK: debug logging set to $DEBUG_LOG_ENABLED, service started"
    fi
else
    echo "ERROR: debug logging set to $DEBUG_LOG_ENABLED, but service failed to start"
    exit 1
fi
