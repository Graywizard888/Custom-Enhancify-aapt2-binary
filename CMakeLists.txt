cmake_minimum_required(VERSION 3.14.2)
project(build-tools)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)

if(ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "armeabi-v7a")
    enable_language(ASM)
elseif(ANDROID_ABI STREQUAL "x86_64" OR ANDROID_ABI STREQUAL "x86")
    enable_language(ASM_NASM)
else()
    message(FATAL_ERROR "Unsupported architecture: ${ANDROID_ABI}")
endif()

# Architecture-specific optimization flags
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(ARCH_FLAGS "-march=armv8-a")
    message(STATUS "Optimizing for ARM64 (armv8-a)")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(ARCH_FLAGS "-march=armv7-a -mfpu=neon")
    message(STATUS "Optimizing for ARMv7 (armv7-a + NEON)")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(ARCH_FLAGS "-march=x86-64 -msse4.2")
    message(STATUS "Optimizing for x86_64 (SSE4.2)")
elseif(ANDROID_ABI STREQUAL "x86")
    set(ARCH_FLAGS "-march=i686 -msse3")
    message(STATUS "Optimizing for x86 (i686 + SSE3)")
endif()

# Aggressive optimization flags WITHOUT LTO
# LTO is incompatible with NDK precompiled system libraries
set(OPT_FLAGS "-O2 ${ARCH_FLAGS}")
set(OPT_FLAGS "${OPT_FLAGS} -fomit-frame-pointer")
set(OPT_FLAGS "${OPT_FLAGS} -ffunction-sections")
set(OPT_FLAGS "${OPT_FLAGS} -fdata-sections")
set(OPT_FLAGS "${OPT_FLAGS} -fvisibility=hidden")
set(OPT_FLAGS "${OPT_FLAGS} -fvisibility-inlines-hidden")

# Additional performance flags
if(ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "armeabi-v7a")
    set(OPT_FLAGS "${OPT_FLAGS} -fno-math-errno -fno-trapping-math")
endif()

# Set global cflags and cxxflags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OPT_FLAGS} -fcolor-diagnostics -fPIC -Wno-attributes -std=gnu11")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OPT_FLAGS} -fcolor-diagnostics -fPIC -Wno-attributes -std=gnu++2a")


# Global link options for Android 15+ 16KB page size support
# This ensures all binaries are compatible with 16KB page size devices
add_link_options(
    "-Wl,-z,max-page-size=16384"
)
# Linker flags and dead code elimination
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static -O2 -Wl,--gc-sections -Wl,--strip-unneeded -Wl,-O2")

# platform tools version
# see the misc/platform_tools_version.h
set(TOOLS_VERSION 36.0.0)
set(SRC ${PROJECT_SOURCE_DIR}/submodules)

# 64-bit off_t for lseek.
add_definitions(-D_FILE_OFFSET_BITS=64)

# protoc options
set(protobuf_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(protobuf_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(protobuf_BUILD_PROTOC_BINARIES OFF CACHE BOOL "" FORCE)
set(protobuf_BUILD_LIBPROTOC ON CACHE BOOL "" FORCE)

# thrid-party libraries
add_subdirectory(submodules/boringssl EXCLUDE_FROM_ALL)
add_subdirectory(submodules/fmtlib EXCLUDE_FROM_ALL)
add_subdirectory(submodules/pcre EXCLUDE_FROM_ALL)
add_subdirectory(submodules/libpng EXCLUDE_FROM_ALL)
add_subdirectory(submodules/jsoncpp EXCLUDE_FROM_ALL)
add_subdirectory(submodules/expat/expat EXCLUDE_FROM_ALL)
add_subdirectory(submodules/protobuf EXCLUDE_FROM_ALL)
add_subdirectory(submodules/googletest EXCLUDE_FROM_ALL)

# building sdk-tools
add_subdirectory(cmake)
