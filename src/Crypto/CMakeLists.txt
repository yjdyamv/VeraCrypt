# Crypto module - cryptographic implementations
# This module contains all low-level crypto algorithms, both C/C++ and assembly.

# -------------------------------------------------------------------
# Platform-specific architecture assembly exclusion helpers
# -------------------------------------------------------------------
if(VERACRYPT_CPU_ARCH MATCHES "^(x86|x64)$")
    set(CRYPTO_X86_OR_X64 TRUE)
else()
    set(CRYPTO_X86_OR_X64 FALSE)
endif()

if(VERACRYPT_CPU_ARCH STREQUAL "x64")
    set(CRYPTO_X64 TRUE)
else()
    set(CRYPTO_X64 FALSE)
endif()

if(VERACRYPT_CPU_ARCH STREQUAL "arm64")
    set(CRYPTO_ARM64 TRUE)
else()
    set(CRYPTO_ARM64 FALSE)
endif()

# -------------------------------------------------------------------
# Core C sources (always compiled, unless using wolfCrypt)
# -------------------------------------------------------------------
if(VERACRYPT_WOLFCRYPT)
    # When wolfCrypt is the crypto backend, only wolfCrypt.c is needed
    set(CRYPTO_CORE_SOURCES wolfCrypt.c)
else()
set(CRYPTO_CORE_SOURCES
    Aeskey.c
    Aestab.c
    blake2s.c
    Camellia.c
    chacha-xmm.c
    chacha256.c
    chachaRng.c
    cpu.c
    jitterentropy-base.c
    kuznyechik.c
    SerpentFast.c
    SerpentFast_simd.cpp
    Sha2.c
    Streebog.c
    t1ha2.c
    t1ha2_selfcheck.c
    t1ha_selfcheck.c
    Twofish.c
    Whirlpool.c

    Argon2/src/blake2/blake2b.c
    Argon2/src/argon2.c
    Argon2/src/core.c
    Argon2/src/ref.c
    Argon2/src/selftest.c
)

# -------------------------------------------------------------------
# Architecture-specific C sources
# -------------------------------------------------------------------
if(CRYPTO_X86_OR_X64)
    list(APPEND CRYPTO_CORE_SOURCES
        blake2s_SSE2.c
        blake2s_SSE41.c
        blake2s_SSSE3.c
        Sha2Intel.c
        Argon2/src/opt_sse2.c
    )
endif()

if(CRYPTO_X64)
    list(APPEND CRYPTO_CORE_SOURCES
        kuznyechik_simd.c
        rdrand.c
    )
    # Aescrypt.c excluded on x64 (assembly version used instead)
elseif(CRYPTO_ARM64)
    list(APPEND CRYPTO_CORE_SOURCES
        Aescrypt.c
        Aes_hw_armv8.c
        sha256_armv8.c
    )
else()
    list(APPEND CRYPTO_CORE_SOURCES
        Aescrypt.c
    )
endif()

endif() # VERACRYPT_WOLFCRYPT

if(NOT VERACRYPT_WOLFCRYPT)

# -------------------------------------------------------------------
# AVX2 optimized Argon2 (x64 only)
# NOTE: On Unix with GCC >= 4.7, this would be compiled with -mavx2
# via OBJECT library. For initial CMake migration, compile with
# baseline flags; SIMD optimization tuning is Phase 2.
# -------------------------------------------------------------------
if(CRYPTO_X64)
    list(APPEND CRYPTO_CORE_SOURCES Argon2/src/opt_avx2.c)
endif()

# -------------------------------------------------------------------
# Assembly sources (NASM + YASM)
# These are added as custom commands that produce object files
# -------------------------------------------------------------------
set(CRYPTO_ASM_OBJECTS "")

# NASM assembly
if(CRYPTO_X64 AND NOT VERACRYPT_NOASM)
    if(NOT CRYPTO_ARM64)
        set(NASM_SOURCES
            Aes_x64.asm
            Aes_hw_cpu.asm
        )

        foreach(ASM_FILE ${NASM_SOURCES})
            get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
            set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}.obj")
            if(MSVC)
                set(NASM_FMT win64)
                set(NASM_EXTRA "")
            elseif(APPLE)
                set(NASM_FMT macho64)
                set(NASM_EXTRA "")
            else()
                set(NASM_FMT elf64)
                set(NASM_EXTRA "")
            endif()
            add_custom_command(
                OUTPUT ${ASM_OBJ}
                COMMAND ${CMAKE_ASM_NASM_COMPILER}
                    -f ${NASM_FMT}
                    -D __BITS__=64
                    -D __YASM__
                    -Xvc -Ox
                    -g
                    ${NASM_EXTRA}
                    -o ${ASM_OBJ}
                    ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
                DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
                COMMENT "NASM: ${ASM_FILE}"
            )
            list(APPEND CRYPTO_ASM_OBJECTS ${ASM_OBJ})
        endforeach()
    endif()
endif()

# YASM assembly — .S files (gas parser) + .asm files (YASM-syntax: ddq, %ifidn)
# NOTE: These use YASM-specific constructs (ddq, %ifidn) incompatible with NASM.
# On Unix, NOASM disables them. On Windows x64 they are required for linking.
# Without YASM, Twofish/Camellia/SHA-256/SHA-512/Argon2-AVX2 asm is skipped.
# Install: https://github.com/yasm/yasm/releases (needs VC++ 2010 runtime)
if(CRYPTO_X64 AND NOT VERACRYPT_NOASM AND NOT CRYPTO_ARM64)
    find_program(YASM_EXECUTABLE yasm)
    if(YASM_EXECUTABLE)
        set(YASM_S_SOURCES
            Twofish_x64.S
            Camellia_aesni_x64.S
            Camellia_x64.S
            sha512-x64-nayuki.S
        )
        foreach(ASM_FILE ${YASM_S_SOURCES})
            get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
            set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_yasm.obj")
            if(MSVC)
                set(YASM_FMT win64)
            elseif(APPLE)
                set(YASM_FMT macho64)
            else()
                set(YASM_FMT elf64)
            endif()
            add_custom_command(
                OUTPUT ${ASM_OBJ}
                COMMAND ${YASM_EXECUTABLE}
                    -f ${YASM_FMT}
                    -D __GNUC__ -D __YASM__ -D WINABI
                    -p gas -Xvc
                    -o ${ASM_OBJ}
                    ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
                DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
                COMMENT "YASM(gas): ${ASM_FILE}"
            )
            list(APPEND CRYPTO_ASM_OBJECTS ${ASM_OBJ})
        endforeach()

        # SHA-256/512 AVX/SSE + Argon2 AVX2 .asm files (YASM syntax without -p gas)
        set(YASM_ASM_SOURCES
            sha256_avx1_x64.asm
            sha256_avx2_x64.asm
            sha256_sse4_x64.asm
            sha512_avx1_x64.asm
            sha512_avx2_x64.asm
            sha512_sse4_x64.asm
            Argon2/src/opt_avx2.asm
        )
        foreach(ASM_FILE ${YASM_ASM_SOURCES})
            get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
            set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_yasm.obj")
            add_custom_command(
                OUTPUT ${ASM_OBJ}
                COMMAND ${YASM_EXECUTABLE}
                    -f ${YASM_FMT}
                    -D __GNUC__ -D __YASM__ -D WINABI
                    -Xvc -Ox
                    -o ${ASM_OBJ}
                    ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
                DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
                COMMENT "YASM: ${ASM_FILE}"
            )
            list(APPEND CRYPTO_ASM_OBJECTS ${ASM_OBJ})
        endforeach()

        message(STATUS "YASM found: gas-parser .S files enabled (Twofish, Camellia, SHA-512)")
    else()
        message(WARNING "YASM not found — Twofish/Camellia/SHA-256/512 asm skipped. "
                "Install yasm for full performance.")
    endif()
endif()

# MASM assembly (MSVC x64 only)
if(CRYPTO_X64 AND MSVC AND NOT CRYPTO_ARM64)
    enable_language(ASM_MASM)
    set(MASM_SOURCES
        rdrand_ml.asm
        rdseed_ml.asm
    )
    foreach(ASM_FILE ${MASM_SOURCES})
        get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
        set(ASM_OBJ "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_masm.obj")
        add_custom_command(
            OUTPUT ${ASM_OBJ}
            COMMAND ml64.exe /D_M_X64 /Fo${ASM_OBJ} /c ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_FILE}
            COMMENT "MASM: ${ASM_FILE}"
        )
        list(APPEND CRYPTO_ASM_OBJECTS ${ASM_OBJ})
    endforeach()
endif()

# -------------------------------------------------------------------
# Create the crypto static library
# -------------------------------------------------------------------
add_library(veracrypt_crypto STATIC
    ${CRYPTO_CORE_SOURCES}
    ${CRYPTO_ASM_OBJECTS}
)

veracrypt_set_base_defines(veracrypt_crypto)
veracrypt_set_warnings(veracrypt_crypto)

# ===========================================================================
# SIMD multi-version compilation
#
# On Unix with GCC/Clang, the same source file is compiled multiple times
# with different ISA extension flags (SSE4.1, SSSE3, SHA-NI, AVX2).
# Each variant becomes an OBJECT library, linked into veracrypt_crypto.
# Runtime dispatch via cpu.c selects the fastest supported variant.
#
# On Windows/MSVC, separate source files handle each SIMD variant, so
# no multi-version OBJECT libraries are needed on that platform.
# ===========================================================================

if(CRYPTO_X86_OR_X64 AND NOT MSVC AND VERACRYPT_SIMD_SUPPORTED)
    include(CheckCCompilerFlag)

    # ---- SSE4.1 variant (blake2s_SSE41.c) ----
    check_c_compiler_flag("-mssse3;-msse4.1" _vc_has_sse41)
    if(_vc_has_sse41)
        veracrypt_add_simd_objects(veracrypt_crypto
            blake2s_SSE41.c
            SUFFIX sse41
            FLAGS -mssse3 -msse4.1
        )
    endif()

    # ---- SSSE3 variant (blake2s_SSSE3.c) ----
    check_c_compiler_flag("-mssse3" _vc_has_ssse3)
    if(_vc_has_ssse3)
        veracrypt_add_simd_objects(veracrypt_crypto
            blake2s_SSSE3.c
            SUFFIX ssse3
            FLAGS -mssse3
        )
    endif()

    # ---- Intel SHA extensions (Sha2Intel.c) ----
    check_c_compiler_flag("-msse4.1;-msha" _vc_has_sha)
    if(_vc_has_sha)
        veracrypt_add_simd_objects(veracrypt_crypto
            Sha2Intel.c
            SUFFIX shani
            FLAGS -mssse3 -msse4.1 -msha
        )
    endif()

    # ---- AVX2 variant (Argon2 opt_avx2.c) ----
    check_c_compiler_flag("-mavx2" _vc_has_avx2)
    if(_vc_has_avx2)
        veracrypt_add_simd_objects(veracrypt_crypto
            Argon2/src/opt_avx2.c
            SUFFIX avx2
            FLAGS -mavx2
        )
    endif()
endif()

# ---- ARMv8 crypto extension (Aes_hw_armv8.c, sha256_armv8.c) ----
if(CRYPTO_ARM64 AND NOT MSVC)
    include(CheckCCompilerFlag)
    check_c_compiler_flag("-march=armv8-a+crypto" _vc_has_armv8_crypto)
    if(_vc_has_armv8_crypto)
        veracrypt_add_simd_objects(veracrypt_crypto
            Aes_hw_armv8.c sha256_armv8.c
            SUFFIX armv8crypto
            FLAGS -march=armv8-a+crypto
        )
    endif()
endif()

# Link all SIMD OBJECT libraries into veracrypt_crypto
veracrypt_collect_simd_objects(veracrypt_crypto)

endif() # NOT VERACRYPT_WOLFCRYPT - end of SIMD/build sections

# ===========================================================================
# Target configuration
# ===========================================================================
if(MSVC)
    target_compile_definitions(veracrypt_crypto PRIVATE WIN32 _LIB)
endif()

if(VERACRYPT_NOAESNI)
    target_compile_definitions(veracrypt_crypto PRIVATE CRYPTOPP_DISABLE_AESNI)
    target_compile_options(veracrypt_crypto PRIVATE -mno-aes)
endif()

# jitterentropy must be compiled without optimization for timing stability
if(NOT MSVC)
    set_source_files_properties(
        jitterentropy-base.c
        PROPERTIES COMPILE_FLAGS "-O0"
    )
endif()
