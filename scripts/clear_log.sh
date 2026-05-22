#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

ensure_config_file
: > "$DEBUG_LOG_FILE"
echo "OK: log cleared"
