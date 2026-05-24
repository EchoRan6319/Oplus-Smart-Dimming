#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

echo "欧加真智能调光"
echo "模块目录：$MODDIR"
echo "WebUI：请点击模块卡片的 WebUI 按钮打开配置界面"
echo

ensure_config_file

start_service() {
    echo "后台服务未运行，正在尝试拉起..."
    start_service_detached
}

if ! service_alive; then
    start_service
fi

if service_alive; then
    PID=$(cat "$PID_FILE" 2>/dev/null)

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "发现应用名单已被删除。"
        echo "已自动重新生成默认应用名单："
        echo "Documents/Oplus_Smart_Dimming/packages.conf"
    else
        echo "应用名单已成功更新。"
        echo "无需重启，切回目标应用即刻生效。"
    fi

    if kill -USR1 "$PID" 2>/dev/null; then
        echo "已通知后台服务重载配置。"
    else
        echo "后台服务正在运行，但重载信号发送失败。"
    fi
    echo "后台服务运行中：PID $PID"
else
    echo "后台服务仍未启动。"
    echo "配置目录：Documents/Oplus_Smart_Dimming"
    echo "启动日志：/data/local/tmp/oplus_smart_dimming.boot.log"
    if [ -f "$BOOT_LOG_FILE" ]; then
        echo "----- 最近启动日志 -----"
        tail -n 8 "$BOOT_LOG_FILE" 2>/dev/null
    fi
fi

sleep 3
