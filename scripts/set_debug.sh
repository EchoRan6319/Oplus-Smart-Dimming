#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

load_debug_config
load_refresh_interval
set_debug_logging "$1"

if reload_running_service; then
    echo "OK: debug logging set to $DEBUG_LOG_ENABLED and service reloaded"
else
    echo "OK: debug logging set to $DEBUG_LOG_ENABLED, service not running"
fi
