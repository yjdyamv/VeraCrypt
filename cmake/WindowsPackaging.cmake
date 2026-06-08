# ============================================================================
# VeraCrypt Windows packaging — CPack NSIS installer
# ============================================================================

if(NOT WIN32)
    return()
endif()

include(CPack)

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
set(VERACRYPT_VERSION "${CPACK_PACKAGE_VERSION}")
if(NOT VERACRYPT_VERSION)
    set(VERACRYPT_VERSION "${PROJECT_VERSION}")
endif()

set(CPACK_PACKAGE_VERSION "${VERACRYPT_VERSION}")
set(CPACK_PACKAGE_VENDOR "AM Crypto")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "VeraCrypt Disk Encryption")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/License.txt")
set(CPACK_PACKAGE_CHECKSUM SHA256)

# ---------------------------------------------------------------------------
# NSIS generator
# ---------------------------------------------------------------------------
set(CPACK_GENERATOR "NSIS;ZIP")
set(CPACK_PACKAGE_NAME "VeraCrypt")
set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${VERACRYPT_VERSION}-Windows-x64")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "VeraCrypt")
set(CPACK_PACKAGE_INSTALL_REGISTRY_KEY "VeraCrypt")
set(CPACK_PACKAGE_EXECUTABLES "VeraCrypt-x64.exe" "VeraCrypt" "VeraCrypt Format-x64.exe" "VeraCrypt Format")

set(CPACK_NSIS_DISPLAY_NAME "VeraCrypt")
set(CPACK_NSIS_PACKAGE_NAME "VeraCrypt ${VERACRYPT_VERSION}")
set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
# Icons not available as .ico; use if/when converted from .png
set(CPACK_NSIS_URL_INFO_ABOUT "https://www.veracrypt.fr")
set(CPACK_NSIS_HELP_LINK "https://www.veracrypt.fr")
set(CPACK_NSIS_MODIFY_PATH OFF)
set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
set(CPACK_NSIS_CREATE_ICONS_EXTRA "
    CreateDirectory '$SMPROGRAMS\\VeraCrypt'
    CreateShortCut '$SMPROGRAMS\\VeraCrypt\\VeraCrypt.lnk' '$INSTDIR\\VeraCrypt-x64.exe'
    CreateShortCut '$SMPROGRAMS\\VeraCrypt\\VeraCrypt Format.lnk' '$INSTDIR\\VeraCrypt Format-x64.exe'
    CreateShortCut '$SMPROGRAMS\\VeraCrypt\\Uninstall.lnk' '$INSTDIR\\Uninstall.exe'
    CreateShortCut '$DESKTOP\\VeraCrypt.lnk' '$INSTDIR\\VeraCrypt-x64.exe'
")
set(CPACK_NSIS_DELETE_ICONS_EXTRA "
    Delete '$SMPROGRAMS\\VeraCrypt\\VeraCrypt.lnk'
    Delete '$SMPROGRAMS\\VeraCrypt\\VeraCrypt Format.lnk'
    Delete '$SMPROGRAMS\\VeraCrypt\\Uninstall.lnk'
    RMDir '$SMPROGRAMS\\VeraCrypt'
    Delete '$DESKTOP\\VeraCrypt.lnk'
")

# ---------------------------------------------------------------------------
# Install rules
# ---------------------------------------------------------------------------

# Executables
install(TARGETS veracrypt_mount
    RUNTIME DESTINATION .
    RENAME VeraCrypt-x64.exe
)
install(TARGETS veracrypt_format
    RUNTIME DESTINATION .
    RENAME "VeraCrypt Format-x64.exe"
)
install(TARGETS veracrypt_expander
    RUNTIME DESTINATION .
    RENAME VeraCryptExpander-x64.exe
)

# Kernel driver
install(TARGETS veracrypt_driver
    LIBRARY DESTINATION .
    RENAME veracrypt-x64.sys
)

# License and documentation
install(FILES "${CMAKE_SOURCE_DIR}/License.txt"
    DESTINATION .
)
install(DIRECTORY "${CMAKE_SOURCE_DIR}/doc/"
    DESTINATION doc
    PATTERN ".git" EXCLUDE
)

# Language files
install(DIRECTORY "${CMAKE_SOURCE_DIR}/Translations/"
    DESTINATION Languages
    FILES_MATCHING
    PATTERN "*.xml"
)

# Icons (available as .png, no .ico files exist yet)

message(STATUS "CPack Windows packaging: NSIS + ZIP")
