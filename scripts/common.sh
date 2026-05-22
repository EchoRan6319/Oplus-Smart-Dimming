#!/system/bin/sh

MODULE_DIR=${0%/*}
case "$MODULE_DIR" in
    */scripts) MODULE_DIR=${MODULE_DIR%/scripts} ;;
esac

CONFIG_DIR="/storage/emulated/0/Documents/Oplus_Smart_Dimming"
CONFIG_FILE="$CONFIG_DIR/packages.conf"
SETTINGS_FILE="$CONFIG_DIR/settings.prop"
DEBUG_LOG_FILE="$CONFIG_DIR/smart_dimming.log"
LEGACY_CONFIG_FILE="$CONFIG_DIR/games.txt"
LEGACY_DEBUG_FLAG_FILE="$CONFIG_DIR/debug_logging.enabled"
LEGACY_LOG_FILE="$CONFIG_DIR/smart_dimming_log.txt"
LEGACY_REFRESH_INTERVAL_FILE="$CONFIG_DIR/refresh_interval.txt"
PID_FILE="/data/local/tmp/oplus_smart_dimming.pid"
FIFO_FILE="/data/local/tmp/oplus_smart_dimming.events"
WATCHDOG_PID_FILE="/data/local/tmp/oplus_smart_dimming.watchdog.pid"
LOGCAT_PID_FILE="/data/local/tmp/oplus_smart_dimming.logcat.pid"
STATE_FILE="/data/local/tmp/oplus_smart_dimming.state"
BOOT_LOG_FILE="/data/local/tmp/oplus_smart_dimming.boot.log"
SETTING_KEY="display_single_pulse_eyeprotection_switch"
DEFAULT_STATE="2"
CLASSIC_STATE="0"
WATCHDOG_INTERVAL="60"
MIN_SYNC_INTERVAL="2"
LAST_WRITTEN_STATE=""
LAST_WRITTEN_PACKAGE=""
DEBUG_LOG_ENABLED="0"
WEBUI_REFRESH_INTERVAL="8"
LAST_SYNC_TS="0"

DEFAULT_PACKAGES='
com.tencent.tmgp.sgame
com.tencent.tmgp.pubgmhd
com.miHoYo.Yuanshen
com.miHoYo.hkrpg
'

wait_for_boot() {
    until [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; do
        sleep 1
    done

    until [ -d "/sdcard" ] || [ -d "/storage/emulated/0" ]; do
        sleep 2
    done

    [ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR"
}

log_boot() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$*" >> "$BOOT_LOG_FILE"
}

ensure_config_file() {
    [ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR"
    migrate_legacy_config

    if [ ! -f "$CONFIG_FILE" ]; then
        {
            echo "# ==================================================="
            echo "# 欧加真智能调光 - 应用名单"
            echo "# ==================================================="
            echo "# 每行一个包名，进入这些应用时切换到【经典低频闪】。"
            echo "# 修改保存后，可在 KernelSU WebUI 点【保存并立即生效】，"
            echo "# 或在模块界面点【执行】按钮触发重载。"
            echo "# ==================================================="
            printf '%s\n' "$DEFAULT_PACKAGES" | sed '/^$/d'
        } > "$CONFIG_FILE"
    fi

    if [ ! -f "$SETTINGS_FILE" ]; then
        write_settings_file
    fi
}

migrate_legacy_config() {
    if [ ! -f "$CONFIG_FILE" ] && [ -f "$LEGACY_CONFIG_FILE" ]; then
        cp "$LEGACY_CONFIG_FILE" "$CONFIG_FILE" 2>/dev/null
    fi

    if [ ! -f "$DEBUG_LOG_FILE" ] && [ -f "$LEGACY_LOG_FILE" ]; then
        mv "$LEGACY_LOG_FILE" "$DEBUG_LOG_FILE" 2>/dev/null
    fi

    if [ ! -f "$SETTINGS_FILE" ]; then
        if [ -f "$LEGACY_DEBUG_FLAG_FILE" ]; then
            DEBUG_LOG_ENABLED="1"
        fi
        if [ -f "$LEGACY_REFRESH_INTERVAL_FILE" ]; then
            WEBUI_REFRESH_INTERVAL=$(normalize_refresh_interval "$(cat "$LEGACY_REFRESH_INTERVAL_FILE" 2>/dev/null)")
        fi
    fi
}

normalize_package_stream() {
    sed 's/\r$//; s/#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//' \
        | grep -E '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$' \
        | sort -u
}

load_selected_packages() {
    ensure_config_file
    SELECTED_PACKAGES=$(normalize_package_stream < "$CONFIG_FILE")
}

load_debug_config() {
    ensure_config_file

    DEBUG_LOG_ENABLED=$(read_prop_value "debug_logging" "0")
    case "$DEBUG_LOG_ENABLED" in
        1|on|true|enabled) DEBUG_LOG_ENABLED="1" ;;
        *) DEBUG_LOG_ENABLED="0" ;;
    esac
}

debug_logging_enabled() {
    [ "$DEBUG_LOG_ENABLED" = "1" ]
}

log_debug() {
    debug_logging_enabled || return 0

    [ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR"
    if [ -f "$DEBUG_LOG_FILE" ]; then
        size=$(wc -c < "$DEBUG_LOG_FILE" 2>/dev/null | tr -d ' ')
        case "$size" in
            ''|*[!0-9]*) size=0 ;;
        esac
        if [ "$size" -gt 524288 ]; then
            mv "$DEBUG_LOG_FILE" "$DEBUG_LOG_FILE.1" 2>/dev/null
        fi
    fi

    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$*" >> "$DEBUG_LOG_FILE"
}

set_debug_logging() {
    ensure_config_file

    case "$1" in
        1|on|true|enable|enabled)
            DEBUG_LOG_ENABLED="1"
            log_debug "debug logging enabled"
            ;;
        *)
            log_debug "debug logging disabled"
            DEBUG_LOG_ENABLED="0"
            ;;
    esac

    write_settings_file
}

normalize_refresh_interval() {
    interval="$1"
    case "$interval" in
        ''|*[!0-9]*) interval="8" ;;
    esac

    if [ "$interval" -lt 1 ] 2>/dev/null; then
        interval="1"
    fi
    if [ "$interval" -gt 10 ] 2>/dev/null; then
        interval="10"
    fi

    printf '%s\n' "$interval"
}

load_refresh_interval() {
    ensure_config_file

    WEBUI_REFRESH_INTERVAL=$(normalize_refresh_interval "$(read_prop_value "refresh_interval" "8")")
}

set_refresh_interval() {
    ensure_config_file
    WEBUI_REFRESH_INTERVAL=$(normalize_refresh_interval "$1")
    write_settings_file
}

read_prop_value() {
    key="$1"
    default_value="$2"

    if [ ! -f "$SETTINGS_FILE" ]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    value=$(
        sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$SETTINGS_FILE" \
            | tail -n 1 \
            | sed 's/[[:space:]]*$//'
    )

    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$default_value"
    fi
}

write_settings_file() {
    [ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR"
    {
        echo "# 欧加真智能调光 - WebUI 设置"
        echo "debug_logging=$DEBUG_LOG_ENABLED"
        echo "refresh_interval=$WEBUI_REFRESH_INTERVAL"
    } > "$SETTINGS_FILE"
}

package_is_selected() {
    target="$1"
    [ -n "$target" ] || return 1

    for pkg in $SELECTED_PACKAGES; do
        [ "$pkg" = "$target" ] && return 0
    done
    return 1
}

is_screen_on() {
    dumpsys power 2>/dev/null | grep -q 'Display Power: state=ON' && return 0
    dumpsys window 2>/dev/null | grep -q 'mScreenOn=true'
}

extract_component_package() {
    sed -n 's/.* \([A-Za-z0-9._$][A-Za-z0-9._$]*\/[.A-Za-z0-9_$][.A-Za-z0-9_$]*\).*/\1/p' \
        | head -n 1 \
        | cut -d/ -f1
}

extract_event_package() {
    line="$1"
    printf '%s\n' "$line" \
        | sed -n 's/.*\([A-Za-z0-9_][A-Za-z0-9_]*\(\.[A-Za-z0-9_][A-Za-z0-9_]*\)\{1,\}\)\/[.A-Za-z0-9_$][.A-Za-z0-9_$]*/\1/p' \
        | head -n 1
}

get_top_package() {
    pkg=$(
        dumpsys window 2>/dev/null \
            | grep -m 1 'mCurrentFocus' \
            | extract_component_package
    )
    if [ -n "$pkg" ]; then
        printf '%s\n' "$pkg"
        return 0
    fi

    dumpsys activity activities 2>/dev/null \
        | grep -m 1 'mResumedActivity' \
        | extract_component_package
}

read_current_state() {
    current=$(settings get secure "$SETTING_KEY" 2>/dev/null)
    case "$current" in
        0|1|2) printf '%s\n' "$current" ;;
        *) printf '%s\n' "-1" ;;
    esac
}

current_timestamp() {
    ts=$(date '+%s' 2>/dev/null)
    case "$ts" in
        ''|*[!0-9]*) ts=0 ;;
    esac
    printf '%s\n' "$ts"
}

sync_allowed() {
    now_ts=$(current_timestamp)

    case "$LAST_SYNC_TS" in
        ''|*[!0-9]*) LAST_SYNC_TS=0 ;;
    esac

    if [ $((now_ts - LAST_SYNC_TS)) -lt "$MIN_SYNC_INTERVAL" ] 2>/dev/null; then
        return 1
    fi

    LAST_SYNC_TS="$now_ts"
    return 0
}

write_state_file() {
    if [ "$LAST_WRITTEN_STATE" = "$CURRENT_STATE" ] && [ "$LAST_WRITTEN_PACKAGE" = "$CURRENT_PACKAGE" ]; then
        return 0
    fi

    {
        echo "current_state=$CURRENT_STATE"
        echo "top_package=$CURRENT_PACKAGE"
        echo "selected_count=$(printf '%s\n' "$SELECTED_PACKAGES" | sed '/^$/d' | wc -l | tr -d ' ')"
        echo "last_update=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    } > "$STATE_FILE"

    LAST_WRITTEN_STATE="$CURRENT_STATE"
    LAST_WRITTEN_PACKAGE="$CURRENT_PACKAGE"
}

apply_target_state() {
    target="$1"
    [ -n "$target" ] || return 1

    if [ "$CURRENT_STATE" != "$target" ]; then
        settings put secure "$SETTING_KEY" "$target"
        log_debug "switch state: package=$CURRENT_PACKAGE target=$target previous=$CURRENT_STATE"
        CURRENT_STATE="$target"
    else
        log_debug "keep state: package=$CURRENT_PACKAGE target=$target"
    fi

    write_state_file
}

compute_target_state() {
    pkg="$1"

    if package_is_selected "$pkg"; then
        printf '%s\n' "$CLASSIC_STATE"
    else
        printf '%s\n' "$DEFAULT_STATE"
    fi
}

sync_state_from_foreground() {
    if ! is_screen_on; then
        log_debug "skip sync: screen off"
        return 0
    fi

    CURRENT_PACKAGE=$(get_top_package)
    log_debug "foreground query: package=$CURRENT_PACKAGE"
    apply_target_state "$(compute_target_state "$CURRENT_PACKAGE")"
}

sync_state_for_package() {
    pkg="$1"

    if ! is_screen_on; then
        log_debug "skip event package=$pkg: screen off"
        return 0
    fi

    if [ -z "$pkg" ]; then
        log_debug "event without package: fallback foreground query"
        sync_state_from_foreground
        return $?
    fi

    CURRENT_PACKAGE="$pkg"
    log_debug "foreground event: package=$CURRENT_PACKAGE"
    apply_target_state "$(compute_target_state "$CURRENT_PACKAGE")"
}

save_packages_from_stream() {
    tmp_file=$(mktemp)
    normalize_package_stream > "$tmp_file"

    {
        echo "# ==================================================="
        echo "# 欧加真智能调光 - 应用名单"
        echo "# ==================================================="
        echo "# 由 WebUI 或 action.sh 自动生成，可手动继续编辑。"
        echo "# 每行一个包名，进入这些应用时切换到【经典低频闪】。"
        echo "# ==================================================="
        cat "$tmp_file"
    } > "$CONFIG_FILE"

    rm -f "$tmp_file"
}

reload_running_service() {
    if [ ! -f "$PID_FILE" ]; then
        return 1
    fi

    service_pid=$(cat "$PID_FILE" 2>/dev/null)
    [ -n "$service_pid" ] || return 1
    [ -d "/proc/$service_pid" ] || return 1

    kill -USR1 "$service_pid"
}

stop_background_helpers() {
    for pid_file in "$WATCHDOG_PID_FILE" "$LOGCAT_PID_FILE"; do
        if [ -f "$pid_file" ]; then
            helper_pid=$(cat "$pid_file" 2>/dev/null)
            [ -n "$helper_pid" ] && kill "$helper_pid" 2>/dev/null
            rm -f "$pid_file"
        fi
    done
}
