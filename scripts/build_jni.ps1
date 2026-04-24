<#
Build native libraries for Android ABIs and place them under android/src/main/jniLibs.

Prerequisites:
- Android NDK installed. Set ANDROID_NDK_HOME to the NDK path or ensure local.properties contains ndk.dir entry.
- CMake installed (the NDK ships cmake or use system cmake).
- A working toolchain file is provided at lib/src/VcpkgAndroid.cmake (repo includes it).

Usage (PowerShell, run from project root):
  .\scripts\build_jni.ps1

This will:
- remove existing android/src/main/jniLibs content
- build for ABIs: arm64-v8a, armeabi-v7a, x86, x86_64
- copy generated lib*.so files to android/src/main/jniLibs/<abi>/
#>
Set-StrictMode -Version Latest

Push-Location (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)\.. | Out-Null

function Write-ErrAndExit($msg) {
  Write-Error $msg
  exit 1
}

Write-Host "Cleaning android/src/main/jniLibs..."
$jniDir = Join-Path -Path "android" -ChildPath "src/main/jniLibs"
if (Test-Path $jniDir) { Remove-Item -Recurse -Force $jniDir }
New-Item -ItemType Directory -Path $jniDir | Out-Null

# Determine Android NDK
$ndk = $Env:ANDROID_NDK_HOME
if (-not $ndk) {
  # try local.properties
  $localProps = "local.properties"
  if (Test-Path $localProps) {
    $content = Get-Content $localProps
    foreach ($line in $content) {
      if ($line -match '^ndk.dir\s*=\s*(.+)$') {
        $ndk = $Matches[1].Trim()
        break
      }
    }
  }
}

if (-not $ndk) { Write-ErrAndExit "ANDROID_NDK_HOME not set and ndk.dir not found in local.properties. Please set ANDROID_NDK_HOME or add ndk.dir to local.properties." }

Write-Host "Using Android NDK at: $ndk"

$abis = @('arm64-v8a','armeabi-v7a','x86','x86_64')
$srcDir = Join-Path -Path "lib" -ChildPath "src"
$buildRoot = Join-Path -Path $PWD -ChildPath "build-android"

if (-not (Test-Path $srcDir)) { Write-ErrAndExit "Source dir $srcDir not found" }

foreach ($abi in $abis) {
  Write-Host "Building ABI: $abi"
  $buildDir = Join-Path -Path $buildRoot -ChildPath $abi
  if (Test-Path $buildDir) { Remove-Item -Recurse -Force $buildDir }
  New-Item -ItemType Directory -Path $buildDir | Out-Null

  Push-Location $buildDir | Out-Null

  $cmakeArgs = @(
    "-DCMAKE_TOOLCHAIN_FILE=$PWD\..\..\lib\src\VcpkgAndroid.cmake",
    "-DANDROID_ABI=$abi",
    "-DANDROID_NDK=$ndk",
    "-DANDROID_NATIVE_API_LEVEL=26",
    "-DCMAKE_BUILD_TYPE=Release",
    "-S $srcDir",
    "-B $buildDir"
  )

  $cmakeCmd = "cmake " + ($cmakeArgs -join ' ')
  Write-Host $cmakeCmd
  cmake @cmakeArgs || Write-ErrAndExit "cmake configuration failed for $abi"

  Write-Host "Building..."
  cmake --build $buildDir --config Release -- -j || Write-ErrAndExit "Build failed for $abi"

  # Find produced .so file(s) - search build dir
  $soFiles = Get-ChildItem -Path $buildDir -Recurse -Filter "*.so" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'libflutter_torrent\.so' }
  if (-not $soFiles -or $soFiles.Count -eq 0) { Write-ErrAndExit "No libflutter_torrent.so found for $abi" }

  $destAbiDir = Join-Path -Path $jniDir -ChildPath $abi
  New-Item -ItemType Directory -Path $destAbiDir | Out-Null
  foreach ($file in $soFiles) {
    Copy-Item -Path $file.FullName -Destination (Join-Path $destAbiDir $file.Name) -Force
  }

  Pop-Location | Out-Null
  Write-Host "Built and copied libs for $abi"
}

Write-Host "All ABIs built and placed under android/src/main/jniLibs"

Pop-Location | Out-Null

