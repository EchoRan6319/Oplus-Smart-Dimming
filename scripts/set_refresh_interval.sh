#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

load_debug_config
load_refresh_interval
set_refresh_interval "$1"
echo "OK: refresh interval set to ${WEBUI_REFRESH_INTERVAL}s"
