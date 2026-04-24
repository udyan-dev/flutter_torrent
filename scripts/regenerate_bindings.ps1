<#
Regenerate Dart FFI bindings using ffigen.

This script attempts to locate libclang. If not found it will attempt to
install LLVM via choco (if available). If installation isn't possible
you must install LLVM/Clang manually and make sure `clang` and
`libclang.dll` are on PATH or set the LIBCLANG_PATH environment variable
to point to libclang.dll.

Usage (PowerShell):
  .\scripts\regenerate_bindings.ps1

Run from project root.
#>
Set-StrictMode -Version Latest

function Write-ErrAndExit($msg) {
  Write-Error $msg
  exit 1
}

Push-Location (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)\.. | Out-Null

Write-Host "Regenerating Dart FFI bindings with ffigen..."

# Locate libclang
$libclangPaths = @(
  "$Env:ProgramFiles\LLVM\bin\libclang.dll",
  "$Env:ProgramFiles(x86)\LLVM\bin\libclang.dll"
)

$found = $false
foreach ($p in $libclangPaths) {
  if (Test-Path $p) {
    Write-Host "Found libclang at $p"
    $Env:LIBCLANG_PATH = $p
    $found = $true
    break
  }
}

if (-not $found) {
  $clangCmd = Get-Command clang -ErrorAction SilentlyContinue
  if ($clangCmd) {
    Write-Host "Found clang executable at $($clangCmd.Path)"
    $found = $true
  }
}

if (-not $found) {
  Write-Host "libclang not found. Attempting to install LLVM via Chocolatey..."
  $choco = Get-Command choco -ErrorAction SilentlyContinue
  if ($null -eq $choco) {
    Write-ErrAndExit "Chocolatey not available. Please install LLVM/Clang and ensure clang/libclang are on PATH or set LIBCLANG_PATH to libclang.dll."
  }

  Write-Host "Installing llvm via choco (requires admin)..."
  choco install llvm -y || Write-ErrAndExit "choco install failed. Please install LLVM manually."

  # Try again
  $p = "$Env:ProgramFiles\LLVM\bin\libclang.dll"
  if (Test-Path $p) { $Env:LIBCLANG_PATH = $p; $found = $true }
}

if (-not $found) {
  Write-ErrAndExit "libclang not found after attempts. Aborting."
}

Write-Host "Running: dart pub get"
dart pub get || Write-ErrAndExit "dart pub get failed"

Write-Host "Running: dart run ffigen --config ffigen.yaml"
dart run ffigen --config ffigen.yaml
$rc = $LASTEXITCODE
if ($rc -ne 0) {
  Write-ErrAndExit "ffigen failed with exit code $rc"
}

Write-Host "ffigen succeeded. Bindings regenerated at lib/flutter_torrent_bindings_generated.dart"

Pop-Location | Out-Null

