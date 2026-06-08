# Core business logic
# On Windows, Core sources are compiled inline in Mount/Format targets.

if(NOT UNIX)
    add_library(veracrypt_core INTERFACE)
    target_link_libraries(veracrypt_core INTERFACE veracrypt_volume veracrypt_common)
    return()
endif()

set(CORE_SOURCES
    CoreBase.cpp
    CoreException.cpp
    FatFormatter.cpp
    HostDevice.cpp
    MountOptions.cpp
    RandomNumberGenerator.cpp
    VolumeCreator.cpp
)

if(UNIX)
    list(APPEND CORE_SOURCES
        Unix/CoreService.cpp
        Unix/CoreServiceRequest.cpp
        Unix/CoreServiceResponse.cpp
        Unix/CoreUnix.cpp
        Unix/${VERACRYPT_PLATFORM}/Core${VERACRYPT_PLATFORM}.cpp
    )

    # macOS also uses FreeBSD core implementation
    if(VERACRYPT_PLATFORM STREQUAL "MacOSX")
        list(APPEND CORE_SOURCES Unix/FreeBSD/CoreFreeBSD.cpp)
    endif()
endif()

if(WIN32)
    # Windows core logic is compiled directly into Mount/Format executables.
    # This library only contains platform-independent core sources.
    # Full Windows core sources will be evaluated in Phase 7.
    message(STATUS "Core: Windows mode - platform-independent sources only (Phase 7)")
endif()

add_library(veracrypt_core STATIC ${CORE_SOURCES})
veracrypt_set_base_defines(veracrypt_core)
veracrypt_set_warnings(veracrypt_core)

target_link_libraries(veracrypt_core PUBLIC
    veracrypt_volume
    veracrypt_platform
    veracrypt_common
)

target_include_directories(veracrypt_core PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/Unix
    ${CMAKE_CURRENT_SOURCE_DIR}/Unix/${VERACRYPT_PLATFORM}
)
