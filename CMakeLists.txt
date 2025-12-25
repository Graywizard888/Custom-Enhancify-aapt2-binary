cmake_minimum_required(VERSION 3.14.2)

# Set policies for newer CMake versions
if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()
if(POLICY CMP0077)
    cmake_policy(SET CMP0077 NEW)
endif()

project(build-tools)

# ============================================================
# CRITICAL FIX: Override find_package for Threads and Protobuf
# Must be placed immediately after project()
# Android Bionic libc has pthreads built-in, no separate library needed
# Protobuf is built from source, prevent external find_package
# ============================================================

# Create the Threads target immediately
add_library(Threads::Threads INTERFACE IMPORTED GLOBAL)

# Set all required cache variables for Threads
set(Threads_FOUND TRUE CACHE BOOL "" FORCE)
set(THREADS_FOUND TRUE CACHE BOOL "" FORCE)
set(CMAKE_THREAD_LIBS_INIT "" CACHE STRING "" FORCE)
set(CMAKE_HAVE_THREADS_LIBRARY TRUE CACHE BOOL "" FORCE)
set(CMAKE_USE_PTHREADS_INIT TRUE CACHE BOOL "" FORCE)
set(CMAKE_USE_WIN32_THREADS_INIT FALSE CACHE BOOL "" FORCE)
set(THREADS_PREFER_PTHREAD_FLAG FALSE CACHE BOOL "" FORCE)

# Override find_package to intercept Threads and Protobuf requests
macro(find_package pkg)
    if("${pkg}" STREQUAL "Threads")
        message(STATUS "Intercepted find_package(Threads) - using Android Bionic pthreads")
        # Already configured above
    elseif("${pkg}" STREQUAL "Protobuf")
        message(STATUS "Intercepted find_package(Protobuf) - using built-from-source protobuf")
        # Don't call the real find_package, just set variables
        # Variables will be set after protobuf is built
    else()
        _find_package(${pkg} ${ARGN})
    endif()
endmacro()

# ============================================================
# END OF PACKAGE OVERRIDES
# ============================================================

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

# Linker flags with aggressive dead code elimination
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static -O2 -Wl,--gc-sections -Wl,--strip-all -Wl,-O2 -Wl,-z,max-page-size=16384")

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

# ============================================================
# EXPAT CROSS-COMPILATION FIX
# Android NDK provides proper off_t via sys/types.h
# Expat's type checks fail during cross-compilation and it tries to 
# #define off_t long, which conflicts with NDK headers
# ============================================================
set(SIZEOF_OFF_T 8 CACHE STRING "Size of off_t" FORCE)
set(off_t "" CACHE STRING "off_t type - empty means use native" FORCE)

# Also fix potential size_t issues for 32-bit builds
if(ANDROID_ABI STREQUAL "armeabi-v7a" OR ANDROID_ABI STREQUAL "x86")
    set(SIZEOF_SIZE_T 4 CACHE STRING "Size of size_t" FORCE)
else()
    set(SIZEOF_SIZE_T 8 CACHE STRING "Size of size_t" FORCE)
endif()

# Ensure expat doesn't redefine other standard types
set(HAVE_SYS_TYPES_H 1 CACHE STRING "" FORCE)
set(STDC_HEADERS 1 CACHE STRING "" FORCE)

# ============================================================
# END OF EXPAT FIX
# ============================================================

#FMTLIB NDK r29 COMPATIBILITY FIX
add_compile_definitions(FMT_USE_CONSTEVAL=0)

# third-party libraries
add_subdirectory(submodules/boringssl EXCLUDE_FROM_ALL)
add_subdirectory(submodules/fmtlib EXCLUDE_FROM_ALL)
add_subdirectory(submodules/pcre EXCLUDE_FROM_ALL)
add_subdirectory(submodules/libpng EXCLUDE_FROM_ALL)
add_subdirectory(submodules/jsoncpp EXCLUDE_FROM_ALL)
add_subdirectory(submodules/expat/expat EXCLUDE_FROM_ALL)
add_subdirectory(submodules/protobuf EXCLUDE_FROM_ALL)

# ============================================================
# PROTOBUF CONFIGURATION
# Set all Protobuf variables after building from source
# This must be done before any subdirectory tries to find_package(Protobuf)
# ============================================================

# Set Protobuf found flags
set(Protobuf_FOUND TRUE)
set(PROTOBUF_FOUND TRUE)
set(Protobuf_FOUND TRUE CACHE BOOL "Protobuf found" FORCE)
set(PROTOBUF_FOUND TRUE CACHE BOOL "Protobuf found" FORCE)

# Set Protobuf library variables
set(Protobuf_LIBRARIES libprotobuf)
set(Protobuf_LIBRARY libprotobuf)
set(PROTOBUF_LIBRARIES libprotobuf)
set(PROTOBUF_LIBRARY libprotobuf)
set(Protobuf_LIBRARIES libprotobuf CACHE STRING "Protobuf libraries" FORCE)
set(Protobuf_LIBRARY libprotobuf CACHE STRING "Protobuf library" FORCE)

# Set Protobuf include directories
set(Protobuf_INCLUDE_DIR "${PROJECT_SOURCE_DIR}/submodules/protobuf/src")
set(Protobuf_INCLUDE_DIRS "${PROJECT_SOURCE_DIR}/submodules/protobuf/src")
set(PROTOBUF_INCLUDE_DIR "${PROJECT_SOURCE_DIR}/submodules/protobuf/src")
set(PROTOBUF_INCLUDE_DIRS "${PROJECT_SOURCE_DIR}/submodules/protobuf/src")
set(Protobuf_INCLUDE_DIR "${PROJECT_SOURCE_DIR}/submodules/protobuf/src" CACHE PATH "Protobuf include directory" FORCE)
set(Protobuf_INCLUDE_DIRS "${PROJECT_SOURCE_DIR}/submodules/protobuf/src" CACHE PATH "Protobuf include directories" FORCE)

# Set Protoc executable
set(Protobuf_PROTOC_EXECUTABLE "/usr/local/bin/protoc")
set(PROTOBUF_PROTOC_EXECUTABLE "/usr/local/bin/protoc")
set(Protobuf_PROTOC_EXECUTABLE "/usr/local/bin/protoc" CACHE FILEPATH "Protoc executable" FORCE)
set(PROTOBUF_PROTOC_EXECUTABLE "/usr/local/bin/protoc" CACHE FILEPATH "Protoc executable" FORCE)

# Set Protobuf Lite library (if used)
if(TARGET libprotobuf-lite)
    set(Protobuf_LITE_LIBRARIES libprotobuf-lite)
    set(Protobuf_LITE_LIBRARY libprotobuf-lite)
    set(PROTOBUF_LITE_LIBRARIES libprotobuf-lite)
    set(PROTOBUF_LITE_LIBRARY libprotobuf-lite)
endif()

# Set Protoc library (if used)
if(TARGET libprotoc)
    set(Protobuf_PROTOC_LIBRARIES libprotoc)
    set(Protobuf_PROTOC_LIBRARY libprotoc)
    set(PROTOBUF_PROTOC_LIBRARIES libprotoc)
    set(PROTOBUF_PROTOC_LIBRARY libprotoc)
endif()

# Create namespace aliases for modern CMake
if(TARGET libprotobuf AND NOT TARGET protobuf::libprotobuf)
    add_library(protobuf::libprotobuf ALIAS libprotobuf)
endif()
if(TARGET libprotoc AND NOT TARGET protobuf::libprotoc)
    add_library(protobuf::libprotoc ALIAS libprotoc)
endif()
if(TARGET libprotobuf-lite AND NOT TARGET protobuf::libprotobuf-lite)
    add_library(protobuf::libprotobuf-lite ALIAS libprotobuf-lite)
endif()

# Debug output
message(STATUS "Protobuf configuration:")
message(STATUS "  Protobuf_FOUND: ${Protobuf_FOUND}")
message(STATUS "  Protobuf_LIBRARIES: ${Protobuf_LIBRARIES}")
message(STATUS "  Protobuf_INCLUDE_DIRS: ${Protobuf_INCLUDE_DIRS}")
message(STATUS "  Protobuf_PROTOC_EXECUTABLE: ${Protobuf_PROTOC_EXECUTABLE}")

# ============================================================
# END OF PROTOBUF CONFIGURATION
# ============================================================

add_subdirectory(submodules/googletest EXCLUDE_FROM_ALL)

# building sdk-tools
add_subdirectory(cmake)
