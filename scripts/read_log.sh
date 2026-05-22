#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

ensure_config_file

if [ ! -f "$DEBUG_LOG_FILE" ]; then
    echo "日志文件尚未生成。开启调试日志后，切换几次应用即可产生记录。"
    exit 0
fi

tail -n 120 "$DEBUG_LOG_FILE" 2>/dev/null
