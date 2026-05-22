#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

load_selected_packages

pm list packages -3 2>/dev/null \
    | sed 's/^package://g' \
    | sort \
    | while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue

        label=$(
            pm dump "$pkg" 2>/dev/null \
                | sed -n "s/.*application-label:'\\(.*\\)'.*/\\1/p" \
                | head -n 1
        )

        [ -n "$label" ] || label="$pkg"
        label=$(printf '%s' "$label" | tr '\t' ' ' | tr '\r' ' ')

        selected=0
        if package_is_selected "$pkg"; then
            selected=1
        fi

        printf '%s\t%s\t%s\n' "$pkg" "$selected" "$label"
    done
