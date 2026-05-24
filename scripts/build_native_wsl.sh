#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NDK_ROOT_DEFAULT="/mnt/c/Users/EchoRan/AppData/Local/Android/Sdk/ndk/30.0.14904198"
NDK_ROOT="${ANDROID_NDK_ROOT:-${NDK_ROOT:-$NDK_ROOT_DEFAULT}}"
TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
API_LEVEL="${ANDROID_API_LEVEL:-24}"
TARGET_TRIPLE="aarch64-linux-android"
TARGET_BIN="$TOOLCHAIN/bin/${TARGET_TRIPLE}${API_LEVEL}-clang++"
WINDOWS_COMPILER="$NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64/bin/${TARGET_TRIPLE}${API_LEVEL}-clang++.cmd"
OUTPUT_DIR="$ROOT_DIR/bin"
BUILD_DIR="$ROOT_DIR/native/build-android"
OUTPUT_BIN="$OUTPUT_DIR/oplus_smart_dimmingd"

if [ -x "$TARGET_BIN" ]; then
    mkdir -p "$OUTPUT_DIR" "$BUILD_DIR"

    "$TARGET_BIN" \
        -std=c++17 \
        -Wall \
        -Wextra \
        -Wpedantic \
        -O2 \
        -static-libstdc++ \
        "$ROOT_DIR"/native/src/*.cpp \
        -o "$BUILD_DIR/oplus_smart_dimmingd"

    cp "$BUILD_DIR/oplus_smart_dimmingd" "$OUTPUT_BIN"

    echo "Built Android daemon:"
    echo "  $OUTPUT_BIN"
    exit 0
fi

if [ -f "$WINDOWS_COMPILER" ]; then
    powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w "$ROOT_DIR")\\scripts\\build_native.ps1"
    exit 0
fi

echo "Android NDK clang++ not found." >&2
echo "Checked:" >&2
echo "  $TARGET_BIN" >&2
echo "  $WINDOWS_COMPILER" >&2
exit 1
