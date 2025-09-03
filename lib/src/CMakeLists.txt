# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

include(VcpkgAndroid.cmake)
include(ExternalProject)

project(flutter_torrent_library VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -Oz -ffunction-sections -fdata-sections -fvisibility=hidden -fmerge-all-constants -fomit-frame-pointer -g0 -DNDEBUG -flto -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Oz -ffunction-sections -fdata-sections -fvisibility=hidden -fvisibility-inlines-hidden -fmerge-all-constants -fomit-frame-pointer -fno-semantic-interposition -g0 -DNDEBUG -flto -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0")

# Enable function and data section stripping
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffunction-sections -fdata-sections")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ffunction-sections -fdata-sections")

# Enable garbage collection of unused sections during linking
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--gc-sections")
# On Windows, build will probably fail due to https://gitlab.kitware.com/cmake/cmake/-/issues/25936
# Set a custom TRANSMISSION_PREFIX env var to avoid this
if (DEFINED ENV{TRANSMISSION_PREFIX})
    SET(TRANSMISSION_PREFIX $ENV{TRANSMISSION_PREFIX})
else ()
    SET(TRANSMISSION_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/transmission-prefix")
endif ()

SET(TRANSMISSION_BUILD_DIR "${TRANSMISSION_PREFIX}/src/transmission-build")

if (LINUX OR ANDROID OR APPLE)
    SET(LIBS
            ${TRANSMISSION_BUILD_DIR}/libtransmission/libtransmission.a
            ${TRANSMISSION_BUILD_DIR}/third-party/dht.bld/pfx/lib/libdht.a
            ${TRANSMISSION_BUILD_DIR}/third-party/jsonsl/libjsonsl.a
            ${TRANSMISSION_BUILD_DIR}/third-party/libb64.bld/src/libb64.a
            ${TRANSMISSION_BUILD_DIR}/third-party/libdeflate.bld/pfx/lib/libdeflate.a
            ${TRANSMISSION_BUILD_DIR}/third-party/libevent.bld/pfx/lib/libevent.a
            ${TRANSMISSION_BUILD_DIR}/third-party/libnatpmp.bld/pfx/lib/libnatpmp.a
            ${TRANSMISSION_BUILD_DIR}/third-party/libpsl.bld/pfx/lib/libpsl.a
            ${TRANSMISSION_BUILD_DIR}/third-party/libutp.bld/libutp.a
            ${TRANSMISSION_BUILD_DIR}/third-party/miniupnpc.bld/pfx/lib/libminiupnpc.a
            ${TRANSMISSION_BUILD_DIR}/third-party/wildmat/libwildmat.a
    )
elseif (WIN32)
    SET(LIBS
            ${TRANSMISSION_BUILD_DIR}/libtransmission/$<CONFIG>/transmission.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/dht.bld/pfx/lib/dht.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/jsonsl/$<CONFIG>/jsonsl.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/libb64.bld/src/$<CONFIG>/b64.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/libdeflate.bld/pfx/lib/deflatestatic.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/libevent.bld/pfx/lib/event.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/libnatpmp.bld/pfx/lib/natpmp.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/libpsl.bld/pfx/lib/psl.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/libutp.bld/$<CONFIG>/utp.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/miniupnpc.bld/pfx/lib/miniupnpc.lib
            ${TRANSMISSION_BUILD_DIR}/third-party/wildmat/$<CONFIG>/wildmat.lib
            Ws2_32
            Crypt32
            Iphlpapi
    )
endif ()

if (LINUX)
    SET(CMAKE_ARGS
            "-DCMAKE_C_FLAGS=-fPIC"
            "-DCMAKE_CXX_FLAGS=-fPIC"
    )
elseif (APPLE)
    message("CMAKE_SYSTEM_NAME ${CMAKE_SYSTEM_NAME}")
    string(REPLACE ";" "$<SEMICOLON>" CMAKE_OSX_ARCHITECTURES_ "${CMAKE_OSX_ARCHITECTURES}")
    if (IOS)
        # D_DARWIN_C_SOURCE has to be set to compile miniupnp
        SET(CMAKE_ARGS
                "-DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES_}"
                "-DCMAKE_C_FLAGS=-I${CMAKE_SOURCE_DIR}/../ios/Classes -D_DARWIN_C_SOURCE"
                "-DCMAKE_CXX_FLAGS=-I${CMAKE_SOURCE_DIR}/../ios/Classes -D_DARWIN_C_SOURCE")
    else ()
        SET(CMAKE_ARGS "-DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES_}")
    endif ()
elseif (ANDROID)
    SET(CMAKE_ARGS
            "-DCMAKE_C_FLAGS=-fPIC -ffile-prefix-map=${TRANSMISSION_PREFIX}=."
            "-DCMAKE_CXX_FLAGS=-fPIC -ffile-prefix-map=${TRANSMISSION_PREFIX}=."
            "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}"
            "-DCMAKE_EXPORT_COMPILE_COMMANDS=${CMAKE_EXPORT_COMPILE_COMMANDS}"
            "-DCMAKE_SYSTEM_VERSION=${CMAKE_SYSTEM_VERSION}"
            "-DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
            "-DANDROID_STL=${ANDROID_STL}"
            "-DANDROID_PLATFORM=${ANDROID_PLATFORM}"
            "-DANDROID_ABI=${ANDROID_ABI}"
            "-DCMAKE_ANDROID_ARCH_ABI=${CMAKE_ANDROID_ARCH_ABI}"
            "-DANDROID_NDK=${ANDROID_NDK}"
            "-DCMAKE_ANDROID_NDK=${CMAKE_ANDROID_NDK}"
    )
endif ()

ExternalProject_Add(transmission
        PREFIX ${TRANSMISSION_PREFIX}
        GIT_REPOSITORY https://github.com/G-Ray/transmission.git
        GIT_TAG f5c3c67a6d8ef0d66f37e9d6686b2ae78a51c606 # on "4.0.x-pikatorrent"
        INSTALL_COMMAND ""
        CMAKE_ARGS
        ${CMAKE_ARGS}
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_C_FLAGS=-Oz -ffunction-sections -fdata-sections -fvisibility=hidden -fmerge-all-constants -fomit-frame-pointer -g0 -DNDEBUG -flto -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"
        "-DCMAKE_CXX_FLAGS=-Oz -ffunction-sections -fdata-sections -fvisibility=hidden -fvisibility-inlines-hidden -fmerge-all-constants -fomit-frame-pointer -fno-semantic-interposition -g0 -DNDEBUG -flto -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"
        "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--gc-sections -Wl,-s -Wl,--as-needed -Wl,--pack-dyn-relocs=android -Wl,--icf=all -Wl,--exclude-libs,ALL -flto"
        "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--gc-sections -Wl,-s -Wl,--as-needed -Wl,--pack-dyn-relocs=android -Wl,--icf=all -Wl,--exclude-libs,ALL -flto"
        "-DVCPKG_INSTALLED_DIR=${VCPKG_INSTALLED_DIR}"
        "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}"
        "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
        "-DVCPKG_TARGET_TRIPLET=${VCPKG_TARGET_TRIPLET}"
        "-DENABLE_GTK=OFF"
        "-DENABLE_QT=OFF"
        "-DENABLE_MAC=OFF"
        "-DREBUILD_WEB=OFF"
        "-DINSTALL_WEB=OFF"
        "-DENABLE_UTILS=OFF"
        "-DENABLE_CLI=OFF"
        "-DENABLE_TESTS=OFF"
        "-DWITH_CRYPTO=openssl"
        "-DENABLE_DAEMON=OFF"
        "-DINSTALL_DOC=OFF"
        "-DINSTALL_LIB=OFF"
        "-DUSE_SYSTEM_EVENT2=OFF"
        "-DUSE_SYSTEM_DEFLATE=OFF"
        "-DUSE_SYSTEM_DHT=OFF"
        "-DUSE_SYSTEM_MINIUPNPC=OFF"
        "-DUSE_SYSTEM_NATPMP=OFF"
        "-DUSE_SYSTEM_UTP=OFF"
        "-DUSE_SYSTEM_B64=OFF"
        "-DUSE_SYSTEM_PSL=OFF"
        BUILD_BYPRODUCTS
        ${LIBS}
)

if (CMAKE_BUILD_TYPE STREQUAL "Release")
    add_custom_command(TARGET flutter_torrent POST_BUILD
            COMMAND ${CMAKE_STRIP} $<TARGET_FILE:flutter_torrent>
    )
endif ()

find_package(CURL REQUIRED)
find_package(OpenSSL REQUIRED)

add_library(flutter_torrent SHARED
        "flutter_torrent.cc"
)

add_dependencies(flutter_torrent transmission)

ExternalProject_Get_property(transmission SOURCE_DIR)
include_directories("${SOURCE_DIR}/libtransmission")

if (APPLE)
    if (IOS)
        set(APPLE_DEPENDENCIES
                ${CMAKE_SOURCE_DIR}/../ios/lib/libcrypto.a
                ${CMAKE_SOURCE_DIR}/../ios/lib/libssl.a
                ${CMAKE_SOURCE_DIR}/../ios/lib/libz.a
                ${CMAKE_SOURCE_DIR}/../ios/lib/libcurl.a
        )
    else ()
        set(APPLE_DEPENDENCIES
                ${CMAKE_SOURCE_DIR}/../macos/lib/libcrypto.a
                ${CMAKE_SOURCE_DIR}/../macos/lib/libssl.a
                ${CMAKE_SOURCE_DIR}/../macos/lib/libz.a
                ${CMAKE_SOURCE_DIR}/../macos/lib/libcurl.a
        )
    endif ()

    # Use unified libs
    SET(DEPENDENCIES
            ${APPLE_DEPENDENCIES}
            "-framework Foundation"
            "-framework SystemConfiguration"
            "-framework Security"
    )
else ()
    SET(DEPENDENCIES
            OpenSSL::Crypto
            OpenSSL::SSL
            CURL::libcurl
    )
endif ()

target_link_libraries(flutter_torrent
        ${DEPENDENCIES}
        "$<$<BOOL:${ANDROID}>:log>"
        ${LIBS}
)

set_target_properties(flutter_torrent PROPERTIES
        PUBLIC_HEADER flutter_torrent.h
        OUTPUT_NAME "flutter_torrent"
)

target_compile_definitions(flutter_torrent PUBLIC DART_SHARED_LIB)

if (ANDROID)
    # Support Android 15 16k page size.
    target_link_options(flutter_torrent PRIVATE "-Wl,-z,max-page-size=16384,--build-id=none,--hash-style=gnu,--icf=all,--as-needed,--pack-dyn-relocs=android,--exclude-libs,ALL")
endif ()