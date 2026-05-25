$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$packageDir = Join-Path $root "build\release-package"
$zipPath = Join-Path $root "build\oplus_smart_dimming_v424_release.zip"

New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
Remove-Item -Recurse -Force (Join-Path $packageDir "*") -ErrorAction SilentlyContinue

$paths = @(
    "module.prop",
    "service.sh",
    "action.sh",
    "customize.sh",
    "META-INF",
    "webroot",
    "bin",
    "icons"
)

foreach ($relativePath in $paths) {
    $source = Join-Path $root $relativePath
    if (Test-Path $source) {
        Copy-Item $source -Destination $packageDir -Recurse
    }
}

$runtimeScriptsDir = Join-Path $packageDir "scripts"
New-Item -ItemType Directory -Force -Path $runtimeScriptsDir | Out-Null

$runtimeScripts = @(
    "common.sh",
    "legacy_loop.sh",
    "list_apps.sh",
    "read_config.sh",
    "read_log.sh",
    "read_state.sh",
    "save_config.sh",
    "set_debug.sh",
    "clear_log.sh",
    "restart_service.sh"
)

foreach ($scriptName in $runtimeScripts) {
    $source = Join-Path (Join-Path $root "scripts") $scriptName
    if (Test-Path $source) {
        Copy-Item $source -Destination $runtimeScriptsDir
    }
}

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $packageRoot = (Resolve-Path $packageDir).Path.TrimEnd("\", "/")
    Get-ChildItem -Path $packageDir -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($packageRoot.Length + 1)
        $entryName = $relative.Replace([System.IO.Path]::DirectorySeparatorChar, "/")
        $entryName = $entryName.Replace([System.IO.Path]::AltDirectorySeparatorChar, "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip,
            $_.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $zip.Dispose()
}

$requiredEntries = @(
    "module.prop",
    "action.sh",
    "service.sh",
    "customize.sh",
    "webroot/index.html",
    "webroot/lib/kernelsu.js",
    "scripts/common.sh",
    "scripts/read_state.sh",
    "scripts/read_config.sh",
    "scripts/save_config.sh",
    "scripts/set_debug.sh",
    "scripts/clear_log.sh",
    "scripts/restart_service.sh",
    "bin/oplus_smart_dimmingd"
)

$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName })
    $badEntries = @($entries | Where-Object { $_ -like "*\*" })
    if ($badEntries.Count -gt 0) {
        throw "Zip contains Windows-style paths: $($badEntries -join ', ')"
    }

    foreach ($entry in $requiredEntries) {
        if ($entries -notcontains $entry) {
            throw "Zip is missing required entry: $entry"
        }
    }
}
finally {
    $zip.Dispose()
}

Get-Item $zipPath | Select-Object FullName, Length, LastWriteTime
