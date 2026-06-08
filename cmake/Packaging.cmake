# ============================================================================
# VeraCrypt CPack packaging configuration
#
# Generates .deb (Debian/Ubuntu) and .rpm (CentOS/Fedora/openSUSE) packages.
# Merged from src/Build/CMakeLists.txt - activated only on Linux.
# ============================================================================

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    return()
endif()

include(CPack)

# ---------------------------------------------------------------------------
# Version (extracted from Common/Tcdefs.h)
# ---------------------------------------------------------------------------
file(STRINGS "${CMAKE_SOURCE_DIR}/src/Common/Tcdefs.h" _ver_line
    REGEX "^[ \t]*#define[ \t]+VERSION_STRING[ \t]")
if(_ver_line)
    string(REGEX MATCH "\"([^\"]*)\"" _match "${_ver_line}")
    if(CMAKE_MATCH_1)
        set(CPACK_PACKAGE_VERSION "${CMAKE_MATCH_1}")
        set(VERACRYPT_VERSION "${CMAKE_MATCH_1}")
    endif()
endif()

if(NOT CPACK_PACKAGE_VERSION)
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
    set(VERACRYPT_VERSION "${PROJECT_VERSION}")
endif()

set(CPACK_PACKAGE_RELEASE "1")

# ---------------------------------------------------------------------------
# Package naming
# ---------------------------------------------------------------------------
if(VERACRYPT_NOGUI)
    set(CPACK_PACKAGE_NAME "veracrypt-console")
    set(VC_CONFLICT_PACKAGE "veracrypt")
else()
    set(CPACK_PACKAGE_NAME "veracrypt")
    set(VC_CONFLICT_PACKAGE "veracrypt-console")
endif()

# ---------------------------------------------------------------------------
# Distro detection
# ---------------------------------------------------------------------------
set(VC_DISTRO "unknown")
set(VC_DISTRO_VERSION "0")

if(EXISTS "/etc/debian_version")
    file(READ "/etc/debian_version" _deb_ver)
    string(REGEX MATCH "([0-9]+\\.[0-9]+)" _ "${_deb_ver}")
    set(VC_DISTRO_VERSION "${CMAKE_MATCH_1}")

    if(EXISTS "/etc/lsb-release")
        file(READ "/etc/lsb-release" _lsb)
        if(_lsb MATCHES "DISTRIB_ID=Ubuntu")
            set(VC_DISTRO "Ubuntu")
            string(REGEX MATCH "DISTRIB_RELEASE=([0-9.]+)" _ "${_lsb}")
            set(VC_DISTRO_VERSION "${CMAKE_MATCH_1}")
        else()
            set(VC_DISTRO "Debian")
        endif()
    else()
        set(VC_DISTRO "Debian")
    endif()

    set(CPACK_GENERATOR "DEB")
    message(STATUS "Packaging: ${VC_DISTRO} ${VC_DISTRO_VERSION} → DEB")

elseif(EXISTS "/etc/centos-release" OR EXISTS "/etc/fedora-release" OR EXISTS "/etc/redhat-release")
    if(EXISTS "/etc/fedora-release")
        set(VC_DISTRO "Fedora")
        file(READ "/etc/fedora-release" _rel)
    elseif(EXISTS "/etc/centos-release")
        set(VC_DISTRO "CentOS")
        file(READ "/etc/centos-release" _rel)
    else()
        set(VC_DISTRO "RHEL")
        file(READ "/etc/redhat-release" _rel)
    endif()
    string(REGEX MATCH "release ([0-9]+)" _ "${_rel}")
    if(CMAKE_MATCH_1)
        set(VC_DISTRO_VERSION "${CMAKE_MATCH_1}")
    endif()

    set(CPACK_GENERATOR "RPM")
    message(STATUS "Packaging: ${VC_DISTRO} ${VC_DISTRO_VERSION} → RPM")

elseif(EXISTS "/etc/os-release")
    file(READ "/etc/os-release" _osrel)
    if(_osrel MATCHES "NAME=\"openSUSE")
        set(VC_DISTRO "openSUSE")
        string(REGEX MATCH "VERSION=\"([0-9.]+)" _ "${_osrel}")
        set(VC_DISTRO_VERSION "${CMAKE_MATCH_1}")
        set(CPACK_GENERATOR "RPM")
        message(STATUS "Packaging: openSUSE ${VC_DISTRO_VERSION} → RPM")
    endif()
endif()

# Detect architecture
if(CPACK_GENERATOR STREQUAL "DEB")
    find_program(DPKG_EXECUTABLE dpkg)
    if(DPKG_EXECUTABLE)
        execute_process(COMMAND ${DPKG_EXECUTABLE} --print-architecture
            OUTPUT_VARIABLE CPACK_DEBIAN_PACKAGE_ARCHITECTURE
            OUTPUT_STRIP_TRAILING_WHITESPACE)
    else()
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
        else()
            set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "i386")
        endif()
    endif()
else()
    execute_process(COMMAND arch
        OUTPUT_VARIABLE CPACK_RPM_PACKAGE_ARCHITECTURE
        OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()

# ---------------------------------------------------------------------------
# FUSE dependency detection (distro-specific package names)
# ---------------------------------------------------------------------------
if(VC_DISTRO STREQUAL "Debian" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "13")
    set(VC_DEB_USE_T64 TRUE)
elseif(VC_DISTRO STREQUAL "Ubuntu" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "24.04")
    set(VC_DEB_USE_T64 TRUE)
else()
    set(VC_DEB_USE_T64 FALSE)
endif()

if(VERACRYPT_WITHFUSE3)
    set(VC_FUSE_DEB "libfuse3-3")
    set(VC_FUSE_RPM "fuse3")
    if(VC_DISTRO STREQUAL "Debian" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "13")
        set(VC_FUSE_DEB "libfuse3-4")
    elseif(VC_DISTRO STREQUAL "Ubuntu" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "25.10")
        set(VC_FUSE_DEB "libfuse3-4")
    endif()
else()
    set(VC_FUSE_RPM "fuse")
    if(VC_DEB_USE_T64)
        set(VC_FUSE_DEB "libfuse2t64")
    else()
        set(VC_FUSE_DEB "libfuse2")
    endif()
endif()

# ---------------------------------------------------------------------------
# CPack metadata
# ---------------------------------------------------------------------------
set(CPACK_PACKAGE_VENDOR "AM Crypto")
set(CPACK_PACKAGE_CONTACT "VeraCrypt Team <veracrypt@amcrypto.jp>")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Disk encryption with strong security based on TrueCrypt")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/License.txt")
set(CPACK_PACKAGE_CHECKSUM SHA256)
set(CPACK_PACKAGE_RELOCATABLE OFF)
set(CPACK_THREADS 1)

# ---------------------------------------------------------------------------
# Package file name
# ---------------------------------------------------------------------------
string(TOLOWER "${VC_DISTRO}-${VC_DISTRO_VERSION}" _distro_slug)
if(CPACK_GENERATOR STREQUAL "DEB")
    string(REGEX REPLACE "[^a-z0-9.-]" "" _distro_slug "${_distro_slug}")
    set(CPACK_PACKAGE_FILE_NAME
        "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${_distro_slug}-${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}")

    # Distro-specific version for repo conflicts (e.g. 1.26.17-1~deb11)
    if(VC_DISTRO STREQUAL "Ubuntu")
        set(CPACK_DEBIAN_PACKAGE_VERSION
            "${CPACK_PACKAGE_VERSION}-${CPACK_PACKAGE_RELEASE}~ubuntu${VC_DISTRO_VERSION}")
    elseif(VC_DISTRO STREQUAL "Debian")
        string(REGEX MATCH "^[0-9]+" _deb_major "${VC_DISTRO_VERSION}")
        set(CPACK_DEBIAN_PACKAGE_VERSION
            "${CPACK_PACKAGE_VERSION}-${CPACK_PACKAGE_RELEASE}~deb${_deb_major}")
    endif()
endif()

# ---------------------------------------------------------------------------
# DEB-specific
# ---------------------------------------------------------------------------
if(CPACK_GENERATOR STREQUAL "DEB")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
    set(CPACK_DEBIAN_PACKAGE_DESCRIPTION "${CPACK_PACKAGE_DESCRIPTION_SUMMARY}")
    set(CPACK_DEBIAN_ARCHIVE_TYPE "gnutar")
    set(CPACK_DEBIAN_COMPRESSION_TYPE "gzip")
    set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
    set(CPACK_DEBIAN_PACKAGE_SECTION "libs")
    set(CPACK_DEBIAN_PACKAGE_CONFLICTS "${VC_CONFLICT_PACKAGE}")

    # Dependencies
    if(VERACRYPT_NOGUI)
        set(CPACK_DEBIAN_PACKAGE_DEPENDS "${VC_FUSE_DEB}, dmsetup, sudo")
    else()
        # GUI: wxWidgets libraries per distro
        if(VC_DISTRO STREQUAL "Debian" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "13")
            set(VC_WX "libwxgtk3.2-1t64")
            set(VC_INDICATOR "libayatana-appindicator3-1")
        elseif(VC_DISTRO STREQUAL "Ubuntu" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "25.04")
            set(VC_WX "libwxgtk3.2-1t64")
            set(VC_INDICATOR "libayatana-appindicator3-1")
        elseif(VC_DISTRO STREQUAL "Ubuntu" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "24.04")
            set(VC_WX "libgtk-3-0t64")
            set(VC_INDICATOR "libayatana-appindicator3-1")
        elseif(VC_DISTRO STREQUAL "Debian" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "12")
            set(VC_WX "libwxgtk3.2-1")
            set(VC_INDICATOR "libayatana-appindicator3-1")
        elseif((VC_DISTRO STREQUAL "Debian" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "10")
            OR (VC_DISTRO STREQUAL "Ubuntu" AND VC_DISTRO_VERSION VERSION_GREATER_EQUAL "18.04"))
            set(VC_WX "libwxgtk3.0-gtk3-0v5")
            set(VC_INDICATOR "libayatana-appindicator3-1")
        else()
            set(VC_WX "libwxgtk3.0-0v5")
            set(VC_INDICATOR "")
        endif()

        set(CPACK_DEBIAN_PACKAGE_DEPENDS
            "${VC_WX}, ${VC_INDICATOR}, ${VC_FUSE_DEB}, dmsetup, sudo")
    endif()
endif()

# ---------------------------------------------------------------------------
# RPM-specific
# ---------------------------------------------------------------------------
if(CPACK_GENERATOR STREQUAL "RPM")
    set(CPACK_RPM_PACKAGE_SUMMARY "${CPACK_PACKAGE_DESCRIPTION_SUMMARY}")
    set(CPACK_RPM_PACKAGE_DESCRIPTION "${CPACK_PACKAGE_DESCRIPTION_SUMMARY}")
    set(CPACK_RPM_PACKAGE_LICENSE "Apache-2.0")
    set(CPACK_RPM_PACKAGE_GROUP "Applications/System")
    set(CPACK_RPM_PACKAGE_VENDOR "${CPACK_PACKAGE_VENDOR}")
    set(CPACK_RPM_PACKAGE_AUTOREQ "no")
    set(CPACK_RPM_PACKAGE_RELOCATABLE "OFF")
    set(CPACK_RPM_PACKAGE_CONFLICTS "${VC_CONFLICT_PACKAGE}")

    # RPM requires
    if(VERACRYPT_NOGUI)
        set(CPACK_RPM_PACKAGE_REQUIRES "${VC_FUSE_RPM}, device-mapper, sudo")
    else()
        find_package(PkgConfig QUIET)
        if(PKG_CONFIG_FOUND)
            pkg_check_modules(GTK3 gtk+-3.0 IMPORTED_TARGET)
        endif()
        if(GTK3_FOUND)
            set(CPACK_RPM_PACKAGE_REQUIRES "${VC_FUSE_RPM}, device-mapper, gtk3, sudo")
        else()
            set(CPACK_RPM_PACKAGE_REQUIRES "${VC_FUSE_RPM}, device-mapper, gtk2, sudo")
        endif()
    endif()

    # Exclude standard dirs from auto file list
    set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
        "/usr" "/usr/bin" "/usr/sbin" "/usr/share"
        "/usr/share/applications" "/usr/share/doc"
        "/usr/share/mime" "/usr/share/mime/packages"
        "/usr/share/pixmaps"
    )
endif()

# ---------------------------------------------------------------------------
# Install rules for packaging
# ---------------------------------------------------------------------------
set(VC_PACKAGE_INSTALL_PREFIX "/usr")
set(CPACK_PACKAGING_INSTALL_PREFIX "${VC_PACKAGE_INSTALL_PREFIX}")

# The install rules use paths relative to CPACK_PACKAGING_INSTALL_PREFIX.
# CMake will prepend CPACK_PACKAGING_INSTALL_PREFIX in the final package.

install(TARGETS veracrypt
    RUNTIME DESTINATION bin
)

if(NOT VERACRYPT_NOGUI)
    install(FILES
        "${CMAKE_SOURCE_DIR}/src/Setup/Linux/veracrypt.desktop"
        DESTINATION share/applications
    )
    install(FILES
        "${CMAKE_SOURCE_DIR}/src/Setup/Linux/veracrypt.xml"
        DESTINATION share/mime/packages
    )
    install(FILES
        "${CMAKE_SOURCE_DIR}/src/Resources/Icons/VeraCrypt-256x256.xpm"
        DESTINATION share/pixmaps
        RENAME veracrypt.xpm
    )
endif()

install(FILES "${CMAKE_SOURCE_DIR}/License.txt"
    DESTINATION share/doc/veracrypt
)

message(STATUS "CPack packaging configured: ${CPACK_GENERATOR}")
