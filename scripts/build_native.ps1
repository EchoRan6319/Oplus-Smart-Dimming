$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$defaultNdk = "C:\Users\EchoRan\AppData\Local\Android\Sdk\ndk\30.0.14904198"
$ndkRoot = if ($env:ANDROID_NDK_ROOT) { $env:ANDROID_NDK_ROOT } elseif ($env:NDK_ROOT) { $env:NDK_ROOT } else { $defaultNdk }
$apiLevel = if ($env:ANDROID_API_LEVEL) { $env:ANDROID_API_LEVEL } else { "24" }
$toolchain = Join-Path $ndkRoot "toolchains\llvm\prebuilt\windows-x86_64\bin"
$compiler = Join-Path $toolchain "aarch64-linux-android$apiLevel-clang++.cmd"
$buildDir = Join-Path $root "native\build-android"
$outputDir = Join-Path $root "bin"
$outputBin = Join-Path $outputDir "oplus_smart_dimmingd"

if (-not (Test-Path $compiler)) {
    throw "Android NDK compiler not found: $compiler"
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$sources = Get-ChildItem (Join-Path $root "native\src\*.cpp") | ForEach-Object { $_.FullName }

& $compiler `
    -std=c++17 `
    -Wall `
    -Wextra `
    -Wpedantic `
    -O2 `
    -static-libstdc++ `
    @sources `
    -o (Join-Path $buildDir "oplus_smart_dimmingd")

Copy-Item (Join-Path $buildDir "oplus_smart_dimmingd") $outputBin -Force

Write-Host "Built Android daemon: $outputBin"
