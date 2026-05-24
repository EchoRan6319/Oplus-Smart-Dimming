#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

echo "正在重启后台服务..."

if restart_service; then
    if service_alive; then
        PID=$(cat "$PID_FILE" 2>/dev/null)
        echo "OK: service restarted, pid=$PID"
        exit 0
    fi
fi

echo "ERROR: service failed to restart"
echo "启动日志：$BOOT_LOG_FILE"
if [ -f "$BOOT_LOG_FILE" ]; then
    echo "----- 最近启动日志 -----"
    tail -n 12 "$BOOT_LOG_FILE" 2>/dev/null
fi
exit 1
