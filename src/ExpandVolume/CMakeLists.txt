# VeraCryptExpander.exe - Windows volume expansion tool
# Mirrors ExpandVolume.vcxproj

if(NOT WIN32)
    return()
endif()

message(STATUS "VeraCryptExpander.exe — Windows volume expansion")

set(EXPANDER_SOURCES
    DlgExpandVolume.cpp
    ExpandVolume.c
    InitDataArea.c
    WinMain.cpp

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
    ../Common/Progress.c
    ../Common/Random.c
    ../Common/Registry.c
    ../Common/Tests.c
    ../Common/Volumes.c
    ../Common/Wipe.c
    ../Common/Xml.c
    ../Common/Xts.c

    ../Setup/SelfExtract.c
    ../Mount/Favorites.cpp
    ../Mount/Hotkeys.c
    ../Mount/MainCom.cpp
    ../Mount/Mount.c
)

add_executable(veracrypt_expander WIN32 ${EXPANDER_SOURCES})

target_compile_definitions(veracrypt_expander PRIVATE
    VCEXPANDER
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

target_include_directories(veracrypt_expander PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/Crypto
    ${CMAKE_SOURCE_DIR}/src/Common
    ${CMAKE_SOURCE_DIR}/src/Common/zlib
    ${CMAKE_SOURCE_DIR}/src/Common/libzip
    ${CMAKE_SOURCE_DIR}/src/Common/lzma
    ${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/include
    ${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/blake2
    ${CMAKE_SOURCE_DIR}/src/PKCS11
    ${CMAKE_SOURCE_DIR}/src/Mount
    ${CMAKE_CURRENT_SOURCE_DIR}
    "${CMAKE_BINARY_DIR}/src/Mount"  # MIDL headers from Mount
)

target_link_libraries(veracrypt_expander PRIVATE
    veracrypt_crypto
    veracrypt_lzma
    veracrypt_zip
    mpr
)

set_source_files_properties(
    ../Common/Dictionary.c
    ../Common/Dlgcode.c
    ../Common/Keyfiles.c
    ../Mount/Mount.c
    PROPERTIES LANGUAGE CXX
)

if(MSVC)
    target_link_options(veracrypt_expander PRIVATE
        /DELAYLOAD:mpr.dll
        /DELAYLOAD:bcrypt.dll
    )
endif()

set_target_properties(veracrypt_expander PROPERTIES
    WIN32_EXECUTABLE TRUE
    RUNTIME_OUTPUT_NAME "VeraCryptExpander"
)

add_dependencies(veracrypt_expander veracrypt_mount veracrypt_format)
