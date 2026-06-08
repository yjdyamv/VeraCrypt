# VeraCrypt Format.exe - Windows volume formatting tool
# Mirrors Format.vcxproj

if(NOT WIN32)
    return()
endif()

message(STATUS "VeraCrypt Format.exe — Windows volume formatting")

set(FORMAT_SOURCES
    FormatCom.cpp
    InPlace.c
    Tcformat.c

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
    ../Common/Fat.c
    ../Common/Format.c
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
)

# MIDL compilation — generates FormatCom_h.h
set(MIDL_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(MIDL_OUTPUTS
    "${MIDL_OUTPUT_DIR}/FormatCom_h.h"
    "${MIDL_OUTPUT_DIR}/FormatCom_i.c"
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
        /header "${MIDL_OUTPUT_DIR}/FormatCom_h.h"
        /out "${MIDL_OUTPUT_DIR}"
        FormatCom.idl
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/FormatCom.idl"
    COMMENT "MIDL: FormatCom.idl"
)

add_executable(veracrypt_format WIN32 ${FORMAT_SOURCES} ${MIDL_OUTPUTS})

target_compile_definitions(veracrypt_format PRIVATE
    VOLFORMAT
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

target_include_directories(veracrypt_format PRIVATE
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

target_link_libraries(veracrypt_format PRIVATE
    veracrypt_crypto
    veracrypt_lzma
    veracrypt_zip
    mpr
)

set_source_files_properties(
    InPlace.c
    Tcformat.c
    ../Common/Dictionary.c
    ../Common/Dlgcode.c
    ../Common/Keyfiles.c
    PROPERTIES LANGUAGE CXX
)

if(MSVC)
    target_link_options(veracrypt_format PRIVATE
        /DELAYLOAD:mpr.dll
        /DELAYLOAD:bcrypt.dll
        /DELAYLOAD:user32.dll
    )
endif()

set_target_properties(veracrypt_format PROPERTIES
    WIN32_EXECUTABLE TRUE
    RUNTIME_OUTPUT_NAME "VeraCrypt Format-x64"
)
