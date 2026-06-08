# ============================================================================
# VeraCrypt reproducible build configuration
#
# Goal: byte-identical binaries from identical sources regardless of
# build path, build host, build user or wall-clock time.
#
# Reference: https://reproducible-builds.org/specs/source-date-epoch/
# ============================================================================

# Derive SOURCE_DATE_EPOCH from git HEAD or Common/Tcdefs.h
if(NOT DEFINED ENV{SOURCE_DATE_EPOCH} AND VERACRYPT_REPRODUCIBLE)
    find_package(Git QUIET)
    if(GIT_FOUND)
        execute_process(
            COMMAND ${GIT_EXECUTABLE} log -1 --format=%ct
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE _sde
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            RESULT_VARIABLE _git_rc
        )
        if(_git_rc EQUAL 0 AND _sde MATCHES "^[0-9]+$")
            set(ENV{SOURCE_DATE_EPOCH} "${_sde}")
        endif()
    endif()

    if(NOT DEFINED ENV{SOURCE_DATE_EPOCH})
        file(STRINGS "${CMAKE_SOURCE_DIR}/src/Common/Tcdefs.h" _ver_line
            REGEX "^[ \t]*#define[ \t]+VERSION_STRING[ \t]")
        if(_ver_line)
            string(REGEX MATCH "\"([^\"]*)\"" _match "${_ver_line}")
            if(CMAKE_MATCH_1)
                message(STATUS "SOURCE_DATE_EPOCH derived from Tcdefs.h version: ${CMAKE_MATCH_1}")
            endif()
        endif()
    endif()
endif()

if(DEFINED ENV{SOURCE_DATE_EPOCH})
    set(SOURCE_DATE_EPOCH "$ENV{SOURCE_DATE_EPOCH}" CACHE STRING "Unix timestamp for reproducible build")
    message(STATUS "SOURCE_DATE_EPOCH = ${SOURCE_DATE_EPOCH}")

    # Clamp file timestamps in install(DIRECTORY) for CPack
    set(ENV{SOURCE_DATE_EPOCH} "${SOURCE_DATE_EPOCH}")

    if(NOT MSVC)
        # Normalize build paths in debug info
        include(CheckCCompilerFlag)
        check_c_compiler_flag("-ffile-prefix-map=${CMAKE_SOURCE_DIR}=." _has_file_prefix_map)
        if(_has_file_prefix_map)
            add_compile_options(-ffile-prefix-map=${CMAKE_SOURCE_DIR}=.)
        else()
            check_c_compiler_flag("-fdebug-prefix-map=${CMAKE_SOURCE_DIR}=." _has_debug_prefix_map)
            if(_has_debug_prefix_map)
                add_compile_options(-fdebug-prefix-map=${CMAKE_SOURCE_DIR}=.)
            endif()
        endif()

        # Drop recorded compiler command line
        check_c_compiler_flag("-fno-record-gcc-switches" _has_no_record)
        if(_has_no_record)
            add_compile_options(-fno-record-gcc-switches)
        endif()

        # Deterministic build-id
        check_c_compiler_flag("-Wl,--build-id=sha1" _has_build_id_sha1)
        if(_has_build_id_sha1)
            add_link_options(-Wl,--build-id=sha1)
        endif()
    endif()
endif()
