# Custom FindThreads.cmake for Android cross-compilation
# Android Bionic libc has pthreads built-in, no separate library needed

message(STATUS "Using custom FindThreads for Android (pthreads built into Bionic libc)")

set(Threads_FOUND TRUE)
set(CMAKE_THREAD_LIBS_INIT "")
set(CMAKE_HAVE_THREADS_LIBRARY 1)
set(CMAKE_USE_WIN32_THREADS_INIT 0)
set(CMAKE_USE_PTHREADS_INIT 1)
set(THREADS_PREFER_PTHREAD_FLAG OFF)

if(NOT TARGET Threads::Threads)
    add_library(Threads::Threads INTERFACE IMPORTED)
    set_target_properties(Threads::Threads PROPERTIES
        INTERFACE_COMPILE_OPTIONS ""
        INTERFACE_LINK_LIBRARIES ""
    )
endif()

set(THREADS_FOUND TRUE)
