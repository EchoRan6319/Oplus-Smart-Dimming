#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

ensure_config_file

start_service() {
    echo "⚠️ 后台服务未运行，正在尝试拉起..."
    start_service_detached
}

if ! service_alive; then
    start_service
fi

if service_alive; then
    PID=$(cat "$PID_FILE" 2>/dev/null)

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚠️ 发现应用名单已被删除！"
        echo "✅ 已自动重新生成默认应用名单："
        echo "📁 Documents/Oplus_Smart_Dimming/packages.conf"
    else
        echo "✅ 应用名单已成功更新！"
        echo "💡 无需重启，切回目标应用即刻生效"
    fi

    kill -USR1 "$PID" 2>/dev/null
    echo "✅ 后台服务运行中：PID $PID"
else
    echo "❌ 后台服务仍未启动！"
    echo "📁 配置目录：Documents/Oplus_Smart_Dimming"
    echo "🧾 启动日志：/data/local/tmp/oplus_smart_dimming.boot.log"
    if [ -f "$BOOT_LOG_FILE" ]; then
        echo "----- 最近启动日志 -----"
        tail -n 8 "$BOOT_LOG_FILE" 2>/dev/null
    fi
fi

# 强行暂停 3 秒，防止 KernelSU 界面闪退，让你能看清弹窗文字
sleep 3
