# Common library
# Contains shared utilities, third-party libraries (lzma, zlib, libzip),
# and framework code used across all modules.

# -------------------------------------------------------------------
# LZMA library
# -------------------------------------------------------------------
add_library(veracrypt_lzma STATIC
    lzma/Alloc.c
    lzma/CpuArch.c
    lzma/LzFind.c
    lzma/LzFindMt.c
    lzma/LzFindOpt.c
    lzma/LzmaDec.c
    lzma/LzmaEnc.c
    lzma/LzmaLib.c
    lzma/Threads.c
)
veracrypt_set_base_defines(veracrypt_lzma)
veracrypt_set_warnings(veracrypt_lzma)
target_compile_definitions(veracrypt_lzma PRIVATE _7ZIP_ST)

# -------------------------------------------------------------------
# Zlib library (minizip dependency)
# -------------------------------------------------------------------
add_library(veracrypt_zlib STATIC
    zlib/adler32.c
    zlib/compress.c
    zlib/crc32.c
    zlib/deflate.c
    zlib/gzclose.c
    zlib/gzlib.c
    zlib/gzread.c
    zlib/gzwrite.c
    zlib/infback.c
    zlib/inffast.c
    zlib/inflate.c
    zlib/inftrees.c
    zlib/trees.c
    zlib/uncompr.c
    zlib/zutil.c
)
veracrypt_set_base_defines(veracrypt_zlib)
veracrypt_set_warnings(veracrypt_zlib)
target_include_directories(veracrypt_zlib PUBLIC zlib)

# -------------------------------------------------------------------
# ZIP/minizip library
# -------------------------------------------------------------------
file(GLOB VC_ZIP_SOURCES
    libzip/*.c
)
# On Windows, keep Win32 file sources (utf8 is required for zip_source_file_create)
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_random_win32\\.c$")
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_random_uwp\\.c$")
# Exclude crypto backends that require external libraries
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_crypto_mbedtls\\.c$")
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_crypto_openssl\\.c$")
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_crypto_gnutls\\.c$")
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_crypto_commoncrypto\\.c$")
# Exclude compression algorithms that need external libraries
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_algorithm_bzip2\\.c$")
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_algorithm_xz\\.c$")
list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_algorithm_zstd\\.c$")
if(NOT UNIX)
    list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_random_unix\\.c$")
    list(FILTER VC_ZIP_SOURCES EXCLUDE REGEX "libzip/zip_source_file_stdio_named\\.c$")
endif()

add_library(veracrypt_zip STATIC ${VC_ZIP_SOURCES})
veracrypt_set_base_defines(veracrypt_zip)
veracrypt_set_warnings(veracrypt_zip)
target_link_libraries(veracrypt_zip PUBLIC veracrypt_zlib)
target_include_directories(veracrypt_zip PUBLIC libzip)
target_compile_definitions(veracrypt_zip PRIVATE HAVE_CONFIG_H ZIP_STATIC)

# -------------------------------------------------------------------
# Core Common library
# -------------------------------------------------------------------
set(COMMON_SOURCES
    CommandAPDU.cpp
    Crc.c
    Crypto.c
    EMVCard.cpp
    EMVToken.cpp
    EncryptionThreadPool.c
    Endian.c
    Fat.c
    Format.c
    GfMul.c
    IccDataExtractor.cpp
    Inflate.c
    Pkcs5.c
    ResponseAPDU.cpp
    SCard.cpp
    SCardLoader.cpp
    SCardManager.cpp
    SCardReader.cpp
    SecurityToken.cpp
    Tests.c
    TLVParser.cpp
    Token.cpp
    Volumes.c
    Wipe.c
    Xml.c
    Xts.c
)

# Windows-UI files (Cmdline, Combo, Dictionary, Dlgcode, Keyfiles,
# Language, Password, Progress, Random, Registry, Cache,
# BootEncryption, BaseCom) are compiled in the Mount/Format targets
# where they have access to Win32 UI APIs and COM.

add_library(veracrypt_common STATIC ${COMMON_SOURCES})
veracrypt_set_base_defines(veracrypt_common)
veracrypt_set_warnings(veracrypt_common)

# Several .c files include C++ headers and must be compiled as C++ on MSVC
# (same as CompileAsCpp in the original vcxproj)
if(MSVC)
    target_compile_definitions(veracrypt_common PRIVATE _HAS_STD_BYTE=0)
    set(VC_COMPILE_AS_CXX_FILES
    )
    foreach(_c_file ${VC_COMPILE_AS_CXX_FILES})
        set_source_files_properties(${_c_file} PROPERTIES LANGUAGE CXX)
    endforeach()
endif()
target_link_libraries(veracrypt_common PUBLIC
    veracrypt_lzma
    veracrypt_zip
)
target_include_directories(veracrypt_common PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
