#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/common.sh"

load_selected_packages
printf '%s\n' "$SELECTED_PACKAGES"
