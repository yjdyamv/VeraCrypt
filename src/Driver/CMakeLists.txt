# ============================================================================
# VeraCrypt Windows kernel-mode driver (veracrypt.sys)
#
# This driver re-compiles most Crypto sources with TC_WINDOWS_DRIVER defined,
# using kernel-mode APIs (ExAllocatePoolWithTag, ntoskrnl, fltmgr, etc.)
# instead of user-mode CRT.
#
# Requires: Windows Driver Kit (WDK) 10.0+
# CMake 3.21+ supports WDK toolchain via VS generator.
# ============================================================================

if(NOT WIN32)
    return()
endif()

message(STATUS "Windows kernel driver target - veracrypt.sys")

# ---------------------------------------------------------------------------
# WDK / Kernel settings
# ---------------------------------------------------------------------------
# MSVC driver build needs kernel-mode environment
if(MSVC)
    set(CMAKE_SYSTEM_VERSION "10.0" CACHE STRING "Windows SDK target version")
    add_compile_definitions(
        _NT_TARGET_VERSION=0xA000006
        TC_WINDOWS_DRIVER
        _NO_CRT_STDIO_INLINE
        UNICODE
        _UNICODE
    )
endif()

# ---------------------------------------------------------------------------
# Driver-specific sources
# ---------------------------------------------------------------------------
set(DRIVER_SOURCES
    # Driver core
    DriveFilter.c
    DumpFilter.c
    EncryptedIoQueue.c
    Ntdriver.c
    Ntvol.c
    VolumeFilter.c
    Driver.rc
)


# ---------------------------------------------------------------------------
# Crypto sources recompiled in kernel mode
# (same files as Crypto.lib, but with TC_WINDOWS_DRIVER)
# ---------------------------------------------------------------------------
set(DRIVER_CRYPTO_SOURCES
    "${CMAKE_SOURCE_DIR}/src/Common/Cache.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Crc.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Crypto.c"
    "${CMAKE_SOURCE_DIR}/src/Common/EncryptionThreadPool.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Endian.c"
    "${CMAKE_SOURCE_DIR}/src/Common/GfMul.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Pkcs5.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Tests.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Volumes.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Wipe.c"
    "${CMAKE_SOURCE_DIR}/src/Common/Xts.c"

    "${CMAKE_SOURCE_DIR}/src/Crypto/Aeskey.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Aestab.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/argon2.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/blake2/blake2b.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/blake2s.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Camellia.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/chacha-xmm.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/chacha256.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/chachaRng.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/cpu.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/jitterentropy-base.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/kuznyechik.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/SerpentFast.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Sha2.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Streebog.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/t1ha2.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/t1ha2_selfcheck.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/t1ha_selfcheck.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Twofish.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Whirlpool.c"

    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/blake2/blake2b.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/argon2.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/core.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/ref.c"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/selftest.c"
)

# Architecture-specific crypto sources
if(VERACRYPT_CPU_ARCH STREQUAL "x64")
    list(APPEND DRIVER_CRYPTO_SOURCES
        "${CMAKE_SOURCE_DIR}/src/Crypto/blake2s_SSE2.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/blake2s_SSE41.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/blake2s_SSSE3.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/Sha2Intel.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/SerpentFast_simd.cpp"
        "${CMAKE_SOURCE_DIR}/src/Crypto/kuznyechik_simd.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/rdrand.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/opt_sse2.c"
    )
elseif(VERACRYPT_CPU_ARCH STREQUAL "arm64")
    list(APPEND DRIVER_CRYPTO_SOURCES
        "${CMAKE_SOURCE_DIR}/src/Crypto/Aescrypt.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/Aes_hw_armv8.c"
        "${CMAKE_SOURCE_DIR}/src/Crypto/sha256_armv8.c"
    )
else()
    list(APPEND DRIVER_CRYPTO_SOURCES
        "${CMAKE_SOURCE_DIR}/src/Crypto/Aescrypt.c"
    )
endif()

# ---------------------------------------------------------------------------
# Create kernel driver target
# ---------------------------------------------------------------------------
add_library(veracrypt_driver MODULE EXCLUDE_FROM_ALL ${DRIVER_SOURCES} ${DRIVER_CRYPTO_SOURCES})

target_include_directories(veracrypt_driver PRIVATE
    "${CMAKE_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/src/Common"
    "${CMAKE_SOURCE_DIR}/src/Crypto"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/include"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/blake2"
    "${CMAKE_BINARY_DIR}"
)

target_compile_definitions(veracrypt_driver PRIVATE
    TC_WINDOWS_DRIVER
    _NO_CRT_STDIO_INLINE
    ARGON2_NO_THREADS
    UNICODE _UNICODE
    WIN32
)

if(VERACRYPT_CPU_ARCH STREQUAL "arm64")
    target_compile_definitions(veracrypt_driver PRIVATE
        _ARM64_ ARM64 _USE_DECLSPECS_FOR_SAL=1 STD_CALL
    )
endif()

# Disable CRT and use kernel libraries
target_link_libraries(veracrypt_driver PRIVATE
    fltmgr.lib
    ntoskrnl.lib
    hal.lib
    wmilib.lib
)

# Set driver properties
set_target_properties(veracrypt_driver PROPERTIES
    SUFFIX ".sys"
    OUTPUT_NAME "veracrypt"
    PREFIX ""
    VS_DRIVER_TYPE "WDM"
)

# Disable Spectre/CFG mitigations for driver (matching original vcxproj)
if(MSVC)
    target_compile_options(veracrypt_driver PRIVATE
        /kernel
        /GS-
        /Qspectre-
    )
endif()

message(STATUS "Kernel driver target configured: veracrypt.sys")
