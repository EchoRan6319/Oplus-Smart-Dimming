#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

ensure_config_file

payload="$1"
if [ -z "$payload" ]; then
    echo "ERROR: empty payload"
    exit 1
fi

tmp_file=$(mktemp)
printf '%s' "$payload" | base64 -d 2>/dev/null > "$tmp_file"

if [ $? -ne 0 ]; then
    rm -f "$tmp_file"
    echo "ERROR: invalid payload"
    exit 1
fi

save_packages_from_stream < "$tmp_file"
rm -f "$tmp_file"

if ensure_service_running; then
    if reload_running_service; then
        echo "OK: saved and reloaded"
    else
        echo "OK: saved, service started"
    fi
else
    echo "ERROR: saved, but service failed to start"
    exit 1
fi
