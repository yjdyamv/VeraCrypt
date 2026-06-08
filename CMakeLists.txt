cmake_minimum_required(VERSION 3.21)

# Lock C++ standard before VSCode/IDE injected flags override it
set(CMAKE_CXX_STANDARD 17 CACHE STRING "C++ standard")
set(CMAKE_CXX_STANDARD_REQUIRED ON CACHE BOOL "Require C++ standard")
set(CMAKE_C_STANDARD 11 CACHE STRING "C standard")
set(CMAKE_C_STANDARD_REQUIRED ON CACHE BOOL "Require C standard")

project(VeraCrypt
    VERSION 1.26.29
    DESCRIPTION "Disk encryption with strong security based on TrueCrypt"
    HOMEPAGE_URL "https://www.veracrypt.fr"
    LANGUAGES C CXX ASM
)

# Enforce x64 — kernel driver + MSVC inline asm require 64-bit
if(CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR "VeraCrypt requires 64-bit build. Set CMake architecture to amd64/x64.")
endif()

if(NOT MSVC)
    enable_language(ASM)
endif()

# NASM assembler - try to find or use specified path
if(NOT DEFINED CMAKE_ASM_NASM_COMPILER)
    find_program(NASM_EXECUTABLE nasm)
    if(NASM_EXECUTABLE)
        set(CMAKE_ASM_NASM_COMPILER "${NASM_EXECUTABLE}")
    endif()
endif()
enable_language(ASM_NASM OPTIONAL)
if(CMAKE_ASM_NASM_COMPILER)
    message(STATUS "NASM assembler: ${CMAKE_ASM_NASM_COMPILER}")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

include(Functions)
include(CompilerWarnings)
include(ReproducibleBuild)

# ============================================================================
# Build options
# ============================================================================
option(VERACRYPT_NOGUI      "Console-only build (no GUI dependencies)"    OFF)
option(VERACRYPT_NOASM      "Exclude modules requiring assembler"         OFF)
option(VERACRYPT_NOSSE2     "Disable SSE2 support"                        OFF)
option(VERACRYPT_WITHFUSE3  "Build with FUSE3 instead of FUSE2"           OFF)
option(VERACRYPT_WOLFCRYPT  "Build with wolfCrypt as crypto provider"     OFF)
option(VERACRYPT_STATIC     "Statically link wxWidgets"                   OFF)
option(VERACRYPT_REPRODUCIBLE "Enable reproducible build"                  ON)
option(VERACRYPT_NOAESNI    "Disable AES-NI support"                      OFF)
option(VERACRYPT_SKIP_SIGNATURE_CHECK "Skip Authenticode signature verification" ON)

set(VERACRYPT_PKCS11_INC "${CMAKE_SOURCE_DIR}/src/PKCS11" CACHE PATH "PKCS#11 include directory")

# ============================================================================
# Platform detection
# ============================================================================
if(WIN32)
    set(VERACRYPT_PLATFORM "Windows")
elseif(APPLE)
    set(VERACRYPT_PLATFORM "MacOSX")
    set(VERACRYPT_OSX_TARGET "12" CACHE STRING "macOS deployment target")
    set(VERACRYPT_OSX_FUSET OFF CACHE BOOL "Use FUSE-T on macOS")
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
    set(VERACRYPT_PLATFORM "FreeBSD")
elseif(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
    set(VERACRYPT_PLATFORM "OpenBSD")
elseif(CMAKE_SYSTEM_NAME MATCHES "^(Linux|SunOS)$")
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(VERACRYPT_PLATFORM "Linux")
    else()
        set(VERACRYPT_PLATFORM "Solaris")
    endif()
else()
    message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
endif()

message(STATUS "VeraCrypt platform: ${VERACRYPT_PLATFORM}")

# ============================================================================
# Architecture detection
# ============================================================================
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(VERACRYPT_ARCH_BITS 64)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|ARM64)$")
        set(VERACRYPT_CPU_ARCH "arm64")
    else()
        set(VERACRYPT_CPU_ARCH "x64")
    endif()
else()
    set(VERACRYPT_ARCH_BITS 32)
    set(VERACRYPT_CPU_ARCH "x86")
endif()

message(STATUS "CPU architecture: ${VERACRYPT_CPU_ARCH} (${VERACRYPT_ARCH_BITS}-bit)")

# SIMD support detection
if(VERACRYPT_CPU_ARCH MATCHES "^(x86|x64)$")
    set(VERACRYPT_SIMD_SUPPORTED TRUE)
else()
    set(VERACRYPT_SIMD_SUPPORTED FALSE)
endif()

if(VERACRYPT_NOSSE2)
    set(VERACRYPT_SIMD_SUPPORTED FALSE)
endif()

# ============================================================================
# Base compile definitions (shared across all targets)
# ============================================================================
set(VERACRYPT_BASE_DEFINES
    _FILE_OFFSET_BITS=64
    _LARGEFILE_SOURCE
    _LARGE_FILES
    ARGON2_NO_THREADS
    $<$<PLATFORM_ID:Linux>:TC_UNIX TC_LINUX>
    $<$<PLATFORM_ID:Darwin>:TC_UNIX TC_BSD TC_MACOSX>
    $<$<PLATFORM_ID:FreeBSD>:TC_UNIX TC_BSD TC_FREEBSD>
    $<$<STREQUAL:${VERACRYPT_CPU_ARCH},x86>:TC_ARCH_X86>
    $<$<STREQUAL:${VERACRYPT_CPU_ARCH},x64>:TC_ARCH_X64>
)

# ============================================================================
# Global compile definitions
# ============================================================================
if(VERACRYPT_PLATFORM STREQUAL "Linux")
    add_compile_definitions(TC_UNIX TC_LINUX)
elseif(VERACRYPT_PLATFORM STREQUAL "MacOSX")
    add_compile_definitions(TC_UNIX TC_BSD TC_MACOSX)
elseif(VERACRYPT_PLATFORM STREQUAL "FreeBSD")
    add_compile_definitions(TC_UNIX TC_BSD TC_FREEBSD)
elseif(VERACRYPT_PLATFORM STREQUAL "OpenBSD")
    add_compile_definitions(TC_UNIX TC_BSD TC_OPENBSD)
elseif(VERACRYPT_PLATFORM STREQUAL "Solaris")
    add_compile_definitions(TC_UNIX TC_SOLARIS)
endif()

add_compile_definitions(
    _FILE_OFFSET_BITS=64
    _LARGEFILE_SOURCE
    _LARGE_FILES
    ARGON2_NO_THREADS
)

if(VERACRYPT_CPU_ARCH STREQUAL "x86")
    add_compile_definitions(TC_ARCH_X86)
elseif(VERACRYPT_CPU_ARCH STREQUAL "x64")
    add_compile_definitions(TC_ARCH_X64)
endif()

if(VERACRYPT_WOLFCRYPT)
    add_compile_definitions(WOLFCRYPT_BACKEND)
    find_library(WOLFSSL_LIBRARY wolfssl REQUIRED)
endif()

if(VERACRYPT_NOGUI)
    add_compile_definitions(TC_NO_GUI wxUSE_GUI=0)
endif()

if(VERACRYPT_NOASM)
    add_compile_definitions(CRYPTOPP_DISABLE_X86ASM)
endif()

# ============================================================================
# Global include directories
# ============================================================================
set(VERACRYPT_INCLUDE_DIRS
    "${CMAKE_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/src/Crypto"
    "${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/include"
    "${VERACRYPT_PKCS11_INC}"
)

# ============================================================================
# Dependencies
# ============================================================================
find_package(PkgConfig QUIET)

if(UNIX)
    include(FindFUSE REQUIRED)
    include(FindwxWidgetsAlt REQUIRED)
endif()

if(VERACRYPT_PLATFORM STREQUAL "Linux")
    pkg_check_modules(PCSC libpcsclite IMPORTED_TARGET)
endif()

# ============================================================================
# Compiler-specific settings
# ============================================================================
if(MSVC)
    add_compile_definitions(_CRT_SECURE_NO_DEPRECATE _CRT_NON_CONFORMING_SWPRINTFS _HAS_STD_BYTE=0 UNICODE _UNICODE)
else()
    set(CMAKE_C_STANDARD 11)
    set(CMAKE_CXX_STANDARD 14)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

# Signature verification skip for development/testing builds
if(VERACRYPT_SKIP_SIGNATURE_CHECK)
    add_compile_definitions(VC_SKIP_OS_DRIVER_REQ_CHECK)
endif()

# ============================================================================
# Subdirectories
# ============================================================================
add_subdirectory(src/Common)
add_subdirectory(src/Crypto)
add_subdirectory(src/Platform)
add_subdirectory(src/Volume)
add_subdirectory(src/Core)

if(UNIX)
    add_subdirectory(src/Driver/Fuse)
    add_subdirectory(src/Main)
endif()

if(WIN32)
    add_subdirectory(src/Mount)
    add_subdirectory(src/Format)
    add_subdirectory(src/ExpandVolume)
    add_subdirectory(src/Driver)
endif()

# ============================================================================
# Packaging (CPack)
# ============================================================================
if(WIN32)
    include(WindowsPackaging)
else()
    include(Packaging)
endif()
