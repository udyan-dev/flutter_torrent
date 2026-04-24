This repository includes helper scripts to regenerate Dart FFI bindings and build Android native libraries.

Regenerating bindings (ffigen)
--------------------------------
Requirements:
- Dart SDK
- libclang (part of LLVM/Clang). On Windows you can install LLVM and ensure libclang.dll is available. Set the environment variable LIBCLANG_PATH to point to libclang.dll if needed.

Run:

```powershell
.\scripts\regenerate_bindings.ps1
```

If the script cannot find libclang, either install LLVM/Clang (via Chocolatey: `choco install llvm -y`) or install manually and set LIBCLANG_PATH.

Building Android native libraries
---------------------------------
Requirements:
- Android NDK (set ANDROID_NDK_HOME or add `ndk.dir` to `local.properties`)
- CMake (NDK ships with a cmake; ensure cmake is callable)

Run:

```powershell
.\scripts\build_jni.ps1
```

This will build for ABIs: arm64-v8a, armeabi-v7a, x86, x86_64 and copy generated .so files to `android/src/main/jniLibs/<abi>/`.

Notes
-----
- These scripts run local toolchain commands and may require admin privileges for installing system packages.
- The repository contains `lib/src/VcpkgAndroid.cmake` which is used by the build script as the toolchain file. Adjust the script if you have a different toolchain setup.

