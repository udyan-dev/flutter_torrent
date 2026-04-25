cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_CLANG_TIDY "" CACHE STRING "" FORCE)
set(CMAKE_C_CLANG_TIDY "" CACHE STRING "" FORCE)
set(CMAKE_EXPORT_COMPILE_COMMANDS OFF CACHE BOOL "" FORCE)

include(VcpkgAndroid.cmake)
include(ExternalProject)

project(flutter_torrent_library VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_VERBOSE_MAKEFILE ON)

if (DEFINED ENV{TRANSMISSION_PREFIX})
    SET(TRANSMISSION_PREFIX $ENV{TRANSMISSION_PREFIX})
else ()
    SET(TRANSMISSION_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/transmission-prefix")
endif ()

SET(TRANSMISSION_BUILD_DIR "${TRANSMISSION_PREFIX}/src/transmission-build")

if (ANDROID)
    SET(LIBS
        ${TRANSMISSION_BUILD_DIR}/libtransmission/libtransmission.a
        ${TRANSMISSION_BUILD_DIR}/third-party/madler-crcany/libMadlerCrcany.a
        ${TRANSMISSION_BUILD_DIR}/third-party/dht.bld/pfx/lib/libdht.a
        ${TRANSMISSION_BUILD_DIR}/third-party/libb64.bld/src/libb64.a
        ${TRANSMISSION_BUILD_DIR}/third-party/libdeflate.bld/pfx/lib/libdeflate.a
        ${TRANSMISSION_BUILD_DIR}/third-party/libevent.bld/lib/libevent_core.a
        ${TRANSMISSION_BUILD_DIR}/third-party/libevent.bld/lib/libevent_extra.a
        ${TRANSMISSION_BUILD_DIR}/third-party/libnatpmp.bld/pfx/lib/libnatpmp.a
        ${TRANSMISSION_BUILD_DIR}/third-party/libpsl.bld/pfx/lib/libpsl.a
        ${TRANSMISSION_BUILD_DIR}/third-party/libutp.bld/libutp.a
        ${TRANSMISSION_BUILD_DIR}/third-party/miniupnp/miniupnpc.bld/pfx/lib/libminiupnpc.a
        ${TRANSMISSION_BUILD_DIR}/third-party/wildmat/libwildmat.a
    )
endif ()

SET(TRANSMISSION_C_FLAGS "-O3 -ffunction-sections -fdata-sections -fvisibility=hidden -DNDEBUG -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -fPIC -D_GNU_SOURCE -ffile-prefix-map=${TRANSMISSION_PREFIX}=.")
SET(TRANSMISSION_CXX_FLAGS "-O3 -ffunction-sections -fdata-sections -fvisibility=hidden -fvisibility-inlines-hidden -DNDEBUG -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -fPIC -ffile-prefix-map=${TRANSMISSION_PREFIX}=.")
SET(TRANSMISSION_SHARED_LINKER_FLAGS "-Wl,--gc-sections -Wl,-s -Wl,--as-needed -Wl,--pack-dyn-relocs=android")
SET(TRANSMISSION_EXE_LINKER_FLAGS "-Wl,--gc-sections -Wl,-s -Wl,--as-needed -Wl,--pack-dyn-relocs=android")

SET(CMAKE_ARGS
    "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}"
    "-DCMAKE_SYSTEM_VERSION=${CMAKE_SYSTEM_VERSION}"
    "-DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
    "-DANDROID_STL=${ANDROID_STL}"
    "-DANDROID_PLATFORM=${ANDROID_PLATFORM}"
    "-DANDROID_ABI=${ANDROID_ABI}"
    "-DANDROID_NDK=${ANDROID_NDK}"
)

ExternalProject_Add(transmission
    PREFIX ${TRANSMISSION_PREFIX}
    GIT_REPOSITORY https://github.com/G-Ray/transmission.git
    GIT_TAG c3ff17924bf623d2434dea585f5d0943809964ec
    INSTALL_COMMAND ""
    CMAKE_ARGS
    ${CMAKE_ARGS}
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_C_FLAGS=${TRANSMISSION_C_FLAGS}"
    "-DCMAKE_CXX_FLAGS=${TRANSMISSION_CXX_FLAGS}"
    "-DCMAKE_SHARED_LINKER_FLAGS=${TRANSMISSION_SHARED_LINKER_FLAGS}"
    "-DCMAKE_EXE_LINKER_FLAGS=${TRANSMISSION_EXE_LINKER_FLAGS}"
    "-DVCPKG_INSTALLED_DIR=${VCPKG_INSTALLED_DIR}"
    "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=${VCPKG_CHAINLOAD_TOOLCHAIN_FILE}"
    "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
    "-DVCPKG_TARGET_TRIPLET=${VCPKG_TARGET_TRIPLET}"
    "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON"
    "-DCMAKE_C_CLANG_TIDY="
    "-DCMAKE_CXX_CLANG_TIDY="
    "-DENABLE_CLANG_TIDY=OFF"
    "-DCLANG_TIDY=CLANG_TIDY-NOTFOUND"
    "-DENABLE_GTK=OFF" "-DENABLE_QT=OFF" "-DENABLE_MAC=OFF" "-DREBUILD_WEB=OFF" "-DINSTALL_WEB=OFF" "-DENABLE_UTILS=OFF" "-DENABLE_CLI=OFF" "-DENABLE_TESTS=OFF" "-DWITH_CRYPTO=openssl" "-DENABLE_DAEMON=OFF" "-DINSTALL_DOC=OFF" "-DINSTALL_LIB=OFF" "-DUSE_SYSTEM_EVENT2=OFF" "-DUSE_SYSTEM_DEFLATE=OFF" "-DUSE_SYSTEM_DHT=OFF" "-DUSE_SYSTEM_MINIUPNPC=OFF" "-DUSE_SYSTEM_NATPMP=OFF" "-DUSE_SYSTEM_UTP=OFF" "-DUSE_SYSTEM_B64=OFF" "-DUSE_SYSTEM_PSL=OFF"
    BUILD_BYPRODUCTS ${LIBS}
)

if(NOT TARGET flutter_torrent)
    add_library(flutter_torrent SHARED "flutter_torrent.cc")
endif()

find_package(CURL REQUIRED)
find_package(OpenSSL REQUIRED)
add_dependencies(flutter_torrent transmission)

ExternalProject_Get_property(transmission SOURCE_DIR)
include_directories("${SOURCE_DIR}")
include_directories("${SOURCE_DIR}/libtransmission")
include_directories("${SOURCE_DIR}/third-party/fmt/include")

SET(DEPENDENCIES OpenSSL::Crypto OpenSSL::SSL CURL::libcurl)

target_compile_features(flutter_torrent PRIVATE cxx_std_20)
target_compile_definitions(flutter_torrent PUBLIC DART_SHARED_LIB)

SET(FLUTTER_TORRENT_RELEASE_OPTIONS -O3 -DNDEBUG -ffunction-sections -fdata-sections -fvisibility=hidden -fvisibility-inlines-hidden -fmerge-all-constants -fomit-frame-pointer -fno-semantic-interposition)

target_compile_options(flutter_torrent PRIVATE "$<$<CONFIG:Release>:${FLUTTER_TORRENT_RELEASE_OPTIONS}>")
target_link_options(flutter_torrent PRIVATE "$<$<CONFIG:Release>:-Wl,--gc-sections;-Wl,--as-needed>")

target_link_libraries(flutter_torrent ${DEPENDENCIES} "$<$<BOOL:${ANDROID}>:log>" ${LIBS})
set_target_properties(flutter_torrent PROPERTIES
    PUBLIC_HEADER flutter_torrent.h
    OUTPUT_NAME "flutter_torrent"
    INTERPROCEDURAL_OPTIMIZATION TRUE
)

if (ANDROID)
    target_link_options(flutter_torrent PRIVATE "-Wl,-z,max-page-size=16384,--build-id=none,--hash-style=gnu,--icf=all,--as-needed,--pack-dyn-relocs=android,--exclude-libs,ALL")
endif ()

if (CMAKE_BUILD_TYPE STREQUAL "Release" AND CMAKE_STRIP)
    add_custom_command(TARGET flutter_torrent POST_BUILD COMMAND ${CMAKE_STRIP} $<TARGET_FILE:flutter_torrent>)
endif ()