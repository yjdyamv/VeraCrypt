# ============================================================================
# VeraCrypt Windows kernel-mode driver (veracrypt.sys)
#
# Kernel driver requires x64 architecture (WDK + 64-bit intrinsics).
# ============================================================================
if(NOT WIN32)
    return()
endif()

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "Kernel driver requires x64 build")
endif()

# Detect WDK SDK version
set(WINSDK_VERSION "10.0.28000.0")
file(GLOB WINSDK_ROOT "C:/Program Files (x86)/Windows Kits/10/Include/${WINSDK_VERSION}")
if(NOT EXISTS "${WINSDK_ROOT}/km/ntifs.h")
    # Fallback to latest installed
    file(GLOB WINSDK_VERSIONS "C:/Program Files (x86)/Windows Kits/10/Include/10.*")
    foreach(_v ${WINSDK_VERSIONS})
        if(EXISTS "${_v}/km/ntifs.h")
            string(REGEX MATCH "10\\.[0-9]+\\.[0-9]+" WINSDK_VERSION "${_v}")
            break()
        endif()
    endforeach()
endif()
if(NOT EXISTS "${WINSDK_ROOT}/km/ntifs.h")
    set(WINSDK_ROOT "C:/Program Files (x86)/Windows Kits/10/Include/${WINSDK_VERSION}")
endif()
set(WINSDK_LIB_ROOT "C:/Program Files (x86)/Windows Kits/10/Lib/${WINSDK_VERSION}/km/x64")

message(STATUS "WDK SDK: ${WINSDK_VERSION}")
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
add_library(veracrypt_driver MODULE ${DRIVER_SOURCES} ${DRIVER_CRYPTO_SOURCES})

target_include_directories(veracrypt_driver PRIVATE
    "${CMAKE_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/src/Common"
    "${CMAKE_SOURCE_DIR}/src/Crypto"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/include"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/blake2"
    "${CMAKE_BINARY_DIR}"
    "${WINSDK_ROOT}/km"
    "${WINSDK_ROOT}/shared"
    "${WINSDK_ROOT}/km/crt"
)

target_compile_definitions(veracrypt_driver PRIVATE
    TC_WINDOWS_DRIVER
    _NO_CRT_STDIO_INLINE
    ARGON2_NO_THREADS
    UNICODE _UNICODE
    WIN32
    _AMD64_
    _WIN64
)

if(VERACRYPT_CPU_ARCH STREQUAL "arm64")
    target_compile_definitions(veracrypt_driver PRIVATE
        _ARM64_ ARM64 _USE_DECLSPECS_FOR_SAL=1 STD_CALL
    )
endif()

# ---------------------------------------------------------------------------
# Assembly sources (NASM + YASM + MASM) — recompiled in kernel mode
# Same files as Crypto library, but built into veracrypt_driver directly.
# ---------------------------------------------------------------------------
set(DRIVER_ASM_OBJECTS "")

# NASM — AES x64 assembly
if(VERACRYPT_CPU_ARCH STREQUAL "x64" AND NOT VERACRYPT_NOASM)
    find_program(NASM_EXECUTABLE nasm)
    if(NASM_EXECUTABLE)
        set(DRV_NASM_SRCS
            "${CMAKE_SOURCE_DIR}/src/Crypto/Aes_x64.asm"
            "${CMAKE_SOURCE_DIR}/src/Crypto/Aes_hw_cpu.asm"
        )
        foreach(ASM_FILE ${DRV_NASM_SRCS})
            get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
            set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_drv.obj")
            add_custom_command(
                OUTPUT ${ASM_OBJ}
                COMMAND ${NASM_EXECUTABLE}
                    -f win64 -D __BITS__=64 -D __YASM__
                    -Xvc -Ox -o ${ASM_OBJ} ${ASM_FILE}
                DEPENDS ${ASM_FILE}
                COMMENT "NASM(drv): ${ASM_NAME}"
            )
            list(APPEND DRIVER_ASM_OBJECTS ${ASM_OBJ})
        endforeach()
    endif()
endif()

# YASM — .S files (gas parser) + .asm files (YASM syntax)
if(VERACRYPT_CPU_ARCH STREQUAL "x64" AND NOT VERACRYPT_NOASM)
    find_program(YASM_EXECUTABLE yasm)
    if(YASM_EXECUTABLE)
        set(DRV_YASM_S_SRCS
            "${CMAKE_SOURCE_DIR}/src/Crypto/Twofish_x64.S"
            "${CMAKE_SOURCE_DIR}/src/Crypto/Camellia_aesni_x64.S"
            "${CMAKE_SOURCE_DIR}/src/Crypto/Camellia_x64.S"
            "${CMAKE_SOURCE_DIR}/src/Crypto/sha512-x64-nayuki.S"
        )
        foreach(ASM_FILE ${DRV_YASM_S_SRCS})
            get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
            set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_drv.obj")
            add_custom_command(
                OUTPUT ${ASM_OBJ}
                COMMAND ${YASM_EXECUTABLE}
                    -f win64 -D __GNUC__ -D __YASM__ -D WINABI
                    -p gas -Xvc -o ${ASM_OBJ} ${ASM_FILE}
                DEPENDS ${ASM_FILE}
                COMMENT "YASM(gas,drv): ${ASM_NAME}"
            )
            list(APPEND DRIVER_ASM_OBJECTS ${ASM_OBJ})
        endforeach()

        set(DRV_YASM_ASM_SRCS
            "${CMAKE_SOURCE_DIR}/src/Crypto/sha256_avx1_x64.asm"
            "${CMAKE_SOURCE_DIR}/src/Crypto/sha256_avx2_x64.asm"
            "${CMAKE_SOURCE_DIR}/src/Crypto/sha256_sse4_x64.asm"
            "${CMAKE_SOURCE_DIR}/src/Crypto/sha512_avx1_x64.asm"
            "${CMAKE_SOURCE_DIR}/src/Crypto/sha512_avx2_x64.asm"
            "${CMAKE_SOURCE_DIR}/src/Crypto/sha512_sse4_x64.asm"
            "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/src/opt_avx2.asm"
        )
        foreach(ASM_FILE ${DRV_YASM_ASM_SRCS})
            get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
            set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_drv.obj")
            add_custom_command(
                OUTPUT ${ASM_OBJ}
                COMMAND ${YASM_EXECUTABLE}
                    -f win64 -D __GNUC__ -D __YASM__ -D WINABI
                    -Xvc -Ox -o ${ASM_OBJ} ${ASM_FILE}
                DEPENDS ${ASM_FILE}
                COMMENT "YASM(drv): ${ASM_NAME}"
            )
            list(APPEND DRIVER_ASM_OBJECTS ${ASM_OBJ})
        endforeach()
    endif()
endif()

# MASM — RDRAND/RDSEED instructions
if(VERACRYPT_CPU_ARCH STREQUAL "x64" AND MSVC AND NOT VERACRYPT_NOASM)
    enable_language(ASM_MASM)
    set(DRV_MASM_SRCS
        "${CMAKE_SOURCE_DIR}/src/Crypto/rdrand_ml.asm"
        "${CMAKE_SOURCE_DIR}/src/Crypto/rdseed_ml.asm"
    )
    foreach(ASM_FILE ${DRV_MASM_SRCS})
        get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
        set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_drv.obj")
        add_custom_command(
            OUTPUT ${ASM_OBJ}
            COMMAND ml64.exe /D_M_X64 /Fo${ASM_OBJ} /c ${ASM_FILE}
            DEPENDS ${ASM_FILE}
            COMMENT "MASM(drv): ${ASM_NAME}"
        )
        list(APPEND DRIVER_ASM_OBJECTS ${ASM_OBJ})
    endforeach()
endif()

# Add assembly objects to driver sources
if(DRIVER_ASM_OBJECTS)
    target_sources(veracrypt_driver PRIVATE ${DRIVER_ASM_OBJECTS})
endif()

# Disable CRT and use kernel libraries
target_link_libraries(veracrypt_driver PRIVATE
    fltmgr.lib
    ntoskrnl.lib
    hal.lib
    wmilib.lib
)
target_link_directories(veracrypt_driver PRIVATE
    "${WINSDK_LIB_ROOT}"
)

# Set driver properties
set_target_properties(veracrypt_driver PROPERTIES
    SUFFIX ".sys"
    OUTPUT_NAME "veracrypt-x64"
    PREFIX ""
)

# Set configuration type to Driver
# Kernel-mode compilation settings (manual WDK, no platform toolset)
if(MSVC)
    target_compile_options(veracrypt_driver PRIVATE
        /kernel /GS- /Qspectre-
    )
    target_link_options(veracrypt_driver PRIVATE
        /NODEFAULTLIB:libucrt.lib
        /NODEFAULTLIB:libucrtd.lib
        /NODEFAULTLIB:libcmt.lib
        /NODEFAULTLIB:libcmtd.lib
        /NODEFAULTLIB:msvcrt.lib
        /NODEFAULTLIB:msvcrtd.lib
        /DRIVER
        /MANIFEST:NO
        /ENTRY:DriverEntry
    )
    set_target_properties(veracrypt_driver PROPERTIES
        MSVC_RUNTIME_LIBRARY ""
        VS_NO_MANIFEST "1"
    )
endif()

message(STATUS "Kernel driver target configured: veracrypt.sys")
