# VeraCrypt.exe - Windows GUI main application
# Mirrors Mount.vcxproj: compiles Common sources directly, links Crypto+Zip+Lzma

if(NOT WIN32)
    return()
endif()

message(STATUS "VeraCrypt.exe (Mount) — Windows GUI application")

set(MOUNT_SOURCES
    # Mount-specific
    Mount.c
    MainCom.cpp
    Hotkeys.c
    Favorites.cpp

    # Smart card / EMV
    ../Common/CommandAPDU.cpp
    ../Common/EMVCard.cpp
    ../Common/EMVToken.cpp
    ../Common/PCSCException.cpp
    ../Common/ResponseAPDU.cpp
    ../Common/SCard.cpp
    ../Common/SCardLoader.cpp
    ../Common/SCardManager.cpp
    ../Common/SCardReader.cpp
    ../Common/TLVParser.cpp
    ../Common/Token.cpp
    ../Common/BaseCom.cpp
    ../Common/BootEncryption.cpp
    ../Common/SecurityToken.cpp

    # Common C sources (linked directly)
    ../Common/Cmdline.c
    ../Common/Combo.c
    ../Common/Crc.c
    ../Common/Crypto.c
    ../Common/Dictionary.c
    ../Common/Dlgcode.c
    ../Common/EncryptionThreadPool.c
    ../Common/Endian.c
    ../Common/GfMul.c
    ../Common/Keyfiles.c
    ../Common/Language.c
    ../Common/Password.c
    ../Common/Pkcs5.c
    ../Common/Random.c
    ../Common/Registry.c
    ../Common/Tests.c
    ../Common/Volumes.c
    ../Common/Wipe.c
    ../Common/Xml.c
    ../Common/Xts.c

    # Setup self-extract
    ../Setup/SelfExtract.c
)

# Resource files
set(MOUNT_RESOURCES
    Mount.rc
    Mount.manifest
)

# MIDL compilation — generates MainCom_h.h, MainCom_i.c, MainCom_p.c
set(MIDL_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(MIDL_OUTPUTS
    "${MIDL_OUTPUT_DIR}/MainCom_h.h"
    "${MIDL_OUTPUT_DIR}/MainCom_i.c"
    "${MIDL_OUTPUT_DIR}/Mount.tlb"
)
add_custom_command(
    OUTPUT ${MIDL_OUTPUTS}
    COMMAND midl.exe
        /nologo
        /char signed
        /env win64
        /Oicf
        /I "${CMAKE_SOURCE_DIR}/src/Common"
        /I "${CMAKE_SOURCE_DIR}/src"
        /header "${MIDL_OUTPUT_DIR}/MainCom_h.h"
        /iid "${MIDL_OUTPUT_DIR}/MainCom_i.c"
        /tlb "${MIDL_OUTPUT_DIR}/Mount.tlb"
        /out "${MIDL_OUTPUT_DIR}"
        MainCom.idl
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/MainCom.idl"
    COMMENT "MIDL: MainCom.idl"
)

add_executable(veracrypt_mount WIN32
    ${MOUNT_SOURCES}
    ${MIDL_OUTPUTS}
    ${MOUNT_RESOURCES}
)

target_compile_definitions(veracrypt_mount PRIVATE
    TCMOUNT
    WIN32
    _WINDOWS
    HAVE_CONFIG_H
    ZIP_STATIC
    _CRT_SECURE_NO_DEPRECATE
    _CRT_NON_CONFORMING_SWPRINTFS
    _HAS_STD_BYTE=0
    UNICODE
    _UNICODE
    $<$<CONFIG:Debug>:DEBUG _DEBUG>
    $<$<CONFIG:Release>:NDEBUG>
)

target_include_directories(veracrypt_mount PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/Crypto
    ${CMAKE_SOURCE_DIR}/src/Common
    ${CMAKE_SOURCE_DIR}/src/PKCS11
    ${CMAKE_SOURCE_DIR}/src/Common/zlib
    ${CMAKE_SOURCE_DIR}/src/Common/libzip
    ${CMAKE_SOURCE_DIR}/src/Common/lzma
    ${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/include
    ${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/blake2
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${MIDL_OUTPUT_DIR}
)

target_link_libraries(veracrypt_mount PRIVATE
    veracrypt_crypto
    veracrypt_lzma
    veracrypt_zip
    mpr
)

# Files compiled as C++ (CompileAsCpp in original vcxproj)
set_source_files_properties(
    Mount.c
    ../Common/Dictionary.c
    ../Common/Dlgcode.c
    ../Common/Keyfiles.c
    PROPERTIES LANGUAGE CXX
)

# Delay-load DLLs (match original vcxproj)
if(MSVC)
    target_link_options(veracrypt_mount PRIVATE
        /DELAYLOAD:mpr.dll
        /DELAYLOAD:bcrypt.dll
        /DELAYLOAD:user32.dll
        /DELAYLOAD:gdi32.dll
        /DELAYLOAD:advapi32.dll
        /DELAYLOAD:shell32.dll
        /DELAYLOAD:ole32.dll
        /DELAYLOAD:oleaut32.dll
        /DELAYLOAD:shlwapi.dll
        /DELAYLOAD:setupapi.dll
        /DELAYLOAD:wintrust.dll
        /DELAYLOAD:comctl32.dll
    )
    set_target_properties(veracrypt_mount PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
endif()

set_target_properties(veracrypt_mount PROPERTIES
    RUNTIME_OUTPUT_NAME "VeraCrypt-x64"
)
