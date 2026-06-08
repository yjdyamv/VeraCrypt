# ============================================================================
# FindFUSE.cmake - detect FUSE2, FUSE3, or FUSE-T
#
# Usage:
#   find_package(FUSE REQUIRED)
#
# Provides:
#   FUSE_FOUND          - TRUE if found
#   FUSE_PACKAGE        - pkg-config package name (fuse, fuse3, or fuse-t)
#   FUSE_VERSION        - major version number (2 or 3)
#   FUSE_INCLUDE_DIRS   - include directories
#   FUSE_LIBRARIES      - libraries to link
# ============================================================================

# Determine which FUSE package to look for
if(APPLE AND VERACRYPT_OSX_FUSET)
    set(_fuse_pkg "fuse-t")
elseif(VERACRYPT_WITHFUSE3)
    set(_fuse_pkg "fuse3")
else()
    set(_fuse_pkg "fuse")
endif()

find_package(PkgConfig QUIET)

if(PKG_CONFIG_FOUND)
    pkg_check_modules(FUSE ${_fuse_pkg})

    if(NOT FUSE_FOUND)
        if(_fuse_pkg STREQUAL "fuse3")
            pkg_check_modules(FUSE fuse)
        elseif(_fuse_pkg STREQUAL "fuse")
            pkg_check_modules(FUSE fuse3)
        endif()
    endif()

    if(FUSE_FOUND)
        execute_process(
            COMMAND ${PKG_CONFIG_EXECUTABLE} --modversion ${_fuse_pkg}
            OUTPUT_VARIABLE _fuse_ver
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(_fuse_ver)
            string(REGEX MATCH "^[0-9]+" FUSE_VERSION "${_fuse_ver}")
        else()
            set(FUSE_VERSION "2")
        endif()

        set(FUSE_PACKAGE ${_fuse_pkg} CACHE STRING "FUSE package name")

        message(STATUS "Found FUSE: ${FUSE_PACKAGE} (version ${FUSE_VERSION})")
    endif()
endif()

if(NOT FUSE_FOUND)
    message(FATAL_ERROR
        "FUSE package '${_fuse_pkg}' not found. "
        "Install it or set VERACRYPT_WITHFUSE3/VERACRYPT_OSX_FUSET appropriately.")
endif()

if(NOT TARGET PkgConfig::FUSE)
    add_library(PkgConfig::FUSE INTERFACE IMPORTED)
    set_target_properties(PkgConfig::FUSE PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${FUSE_INCLUDE_DIRS}"
        INTERFACE_LINK_LIBRARIES "${FUSE_LIBRARIES}"
        INTERFACE_COMPILE_OPTIONS "${FUSE_CFLAGS_OTHER}"
    )
endif()
