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

# Enable Link Time Optimization globally
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)

# Architecture-specific optimization flags
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(ARCH_FLAGS "-march=armv8-a")
    message(STATUS "Building for ARM64 (armv8-a)")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(ARCH_FLAGS "-march=armv7-a" "-mfpu=neon")
    message(STATUS "Building for ARMv7 (armv7-a + NEON)")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(ARCH_FLAGS "-march=x86-64")
    message(STATUS "Building for x86_64")
elseif(ANDROID_ABI STREQUAL "x86")
    set(ARCH_FLAGS "-march=i686")
    message(STATUS "Building for x86 (i686)")
endif()

# Apply optimization flags
add_compile_options(
    -O3
    ${ARCH_FLAGS}
    -fcolor-diagnostics
    -fPIC
    -Wno-attributes
    $<$<COMPILE_LANGUAGE:C>:-std=gnu11>
    $<$<COMPILE_LANGUAGE:CXX>:-std=gnu++2a>
)

# Linker flags
add_link_options(
    -static
    -O3
    -flto
)

# platform tools version
# see the misc/platform_tools_version.h
set(TOOLS_VERSION 35.0.2)
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
