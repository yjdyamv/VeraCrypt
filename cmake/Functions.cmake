# ============================================================================
# VeraCrypt CMake macro and function library
# ============================================================================

# ---------------------------------------------------------------------------
# veracrypt_add_simd_objects - compile sources with SIMD-specific flags
#
# Usage:
#   veracrypt_add_simd_objects(<target_name> <sources> SUFFIX <suffix>
#                              FLAGS <compile_flags...>)
#
# Creates an OBJECT library compiling the given sources with extra flags.
# The OBJECT library can then be linked into a static library.
# ---------------------------------------------------------------------------
function(veracrypt_add_simd_objects BASE_TARGET SOURCES)
    set(options "")
    set(oneValueArgs SUFFIX)
    set(multiValueArgs FLAGS)
    cmake_parse_arguments(VASIMD "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT VASIMD_SUFFIX)
        message(FATAL_ERROR "veracrypt_add_simd_objects requires SUFFIX argument")
    endif()

    set(OBJ_TARGET "${BASE_TARGET}_simd_${VASIMD_SUFFIX}")
    add_library(${OBJ_TARGET} OBJECT ${SOURCES})

    target_include_directories(${OBJ_TARGET} PRIVATE ${VERACRYPT_INCLUDE_DIRS})
    target_compile_definitions(${OBJ_TARGET} PRIVATE
        ${VERACRYPT_BASE_DEFINES}
        $<$<CONFIG:Debug>:DEBUG _DEBUG>
    )

    if(VASIMD_FLAGS)
        target_compile_options(${OBJ_TARGET} PRIVATE ${VASIMD_FLAGS})
    endif()

    set_property(TARGET ${OBJ_TARGET} PROPERTY POSITION_INDEPENDENT_CODE ON)
    set_property(GLOBAL APPEND PROPERTY "${BASE_TARGET}_OBJECTS" ${OBJ_TARGET})
    set_property(GLOBAL PROPERTY "${OBJ_TARGET}_CREATED" TRUE)
endfunction()

# ---------------------------------------------------------------------------
# veracrypt_collect_simd_objects - link all SIMD object libraries into target
# ---------------------------------------------------------------------------
function(veracrypt_collect_simd_objects TARGET)
    get_property(SIMD_LIBS GLOBAL PROPERTY "${TARGET}_OBJECTS")
    if(SIMD_LIBS)
        target_link_libraries(${TARGET} PRIVATE ${SIMD_LIBS})
        get_property(SIMD_LIBS_SET GLOBAL PROPERTY "${TARGET}_OBJECTS_LINKED" SET)
    endif()
endfunction()

# ---------------------------------------------------------------------------
# veracrypt_add_nasm_asm - assemble NASM .asm files
#
# Usage:
#   veracrypt_add_nasm_asm(<target> <asm_files...>)
#
# Assembles .asm files with NASM and adds the resulting objects to the target.
# On Windows, uses win64/win32 format. On Unix, uses elf64/elf32.
# ---------------------------------------------------------------------------
function(veracrypt_add_nasm_asm TARGET)
    if(VERACRYPT_NOASM)
        return()
    endif()

    set(ASM_FILES ${ARGN})

    if(MSVC)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(NASM_FORMAT win64)
            set(NASM_ARCH_FLAG "")
        else()
            set(NASM_FORMAT win32)
            set(NASM_ARCH_FLAG "--prefix _")
        endif()
    else()
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(NASM_FORMAT elf64)
        else()
            set(NASM_FORMAT elf32)
        endif()
    endif()

    foreach(ASM_FILE ${ASM_FILES})
        get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
        set(OBJ_FILE "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}.obj")
        add_custom_command(
            OUTPUT ${OBJ_FILE}
            COMMAND ${CMAKE_ASM_NASM_COMPILER}
                -f ${NASM_FORMAT}
                -D __BITS__=${VERACRYPT_ARCH_BITS}
                -D __YASM__
                -Xvc
                -Ox
                $<$<CONFIG:Debug>:-g>
                ${NASM_ARCH_FLAG}
                -o ${OBJ_FILE}
                ${ASM_FILE}
            DEPENDS ${ASM_FILE}
            COMMENT "Assembling ${ASM_NAME}.asm (NASM)"
        )
        target_sources(${TARGET} PRIVATE ${OBJ_FILE})
    endforeach()
endfunction()

# ---------------------------------------------------------------------------
# veracrypt_add_yasm_asm - assemble YASM .S or .asm files
# ---------------------------------------------------------------------------
function(veracrypt_add_yasm_asm TARGET)
    if(VERACRYPT_NOASM)
        return()
    endif()

    set(ASM_FILES ${ARGN})

    find_program(YASM_EXECUTABLE yasm)
    if(NOT YASM_EXECUTABLE)
        message(WARNING "YASM not found, skipping assembly files")
        return()
    endif()

    if(MSVC)
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(YASM_FORMAT win64)
        else()
            set(YASM_FORMAT win32)
        endif()
    elseif(APPLE)
        set(YASM_FORMAT macho64)
    else()
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(YASM_FORMAT elf64)
        else()
            set(YASM_FORMAT elf32)
        endif()
    endif()

    foreach(ASM_FILE ${ASM_FILES})
        get_filename_component(ASM_NAME ${ASM_FILE} NAME_WE)
        set(OBJ_FILE "${CMAKE_CURRENT_BINARY_DIR}/${ASM_NAME}_yasm.obj")
        add_custom_command(
            OUTPUT ${OBJ_FILE}
            COMMAND ${YASM_EXECUTABLE}
                -f ${YASM_FORMAT}
                -D __GNUC__
                -D __YASM__
                -D WINABI
                -p gas
                -o ${OBJ_FILE}
                ${ASM_FILE}
            DEPENDS ${ASM_FILE}
            COMMENT "Assembling ${ASM_NAME} (YASM)"
        )
        target_sources(${TARGET} PRIVATE ${OBJ_FILE})
    endforeach()
endfunction()

# ---------------------------------------------------------------------------
# veracrypt_embed_resource - convert binary files to C headers
#
# Usage:
#   veracrypt_embed_resource(<output_header> <input_file>)
#
# Equivalent to the Makefile rule: od | tr | sed → .h
# ---------------------------------------------------------------------------
function(veracrypt_embed_resource OUTPUT INPUT)
    get_filename_component(INPUT_DIR ${INPUT} DIRECTORY)
    get_filename_component(INPUT_NAME ${INPUT} NAME)

    if(WIN32)
        add_custom_command(
            OUTPUT ${OUTPUT}
            COMMAND powershell -NoProfile -Command
                "[byte[]]`$bytes = Get-Content -Path '${INPUT}' -Encoding Byte -Raw; `$bytes -join ', ' | Out-File -Encoding ASCII '${OUTPUT}'"
            DEPENDS ${INPUT}
            COMMENT "Embedding ${INPUT_NAME} -> ${OUTPUT}"
        )
    else()
        add_custom_command(
            OUTPUT ${OUTPUT}
            COMMAND od -v -t u1 -A n ${INPUT} | tr '\n' ' ' | tr -s ' ' ',' | sed -e 's/^,//g' -e 's/,$$//g' > ${OUTPUT}
            DEPENDS ${INPUT}
            COMMENT "Embedding ${INPUT_NAME} -> ${OUTPUT}"
        )
    endif()
endfunction()

# ---------------------------------------------------------------------------
# veracrypt_set_base_defines - set common compile definitions for a target
# ---------------------------------------------------------------------------
function(veracrypt_set_base_defines TARGET)
    target_compile_definitions(${TARGET} PRIVATE
        ${VERACRYPT_BASE_DEFINES}
        $<$<CONFIG:Debug>:DEBUG _DEBUG>
        $<$<CONFIG:Release>:NDEBUG>
        $<$<PLATFORM_ID:Linux>:TC_UNIX TC_LINUX>
        $<$<PLATFORM_ID:Darwin>:TC_UNIX TC_BSD TC_MACOSX>
        TC_ARCH_$<UPPER_CASE:${VERACRYPT_CPU_ARCH}>
        ARGON2_NO_THREADS
    )
    target_include_directories(${TARGET} PRIVATE ${VERACRYPT_INCLUDE_DIRS})
endfunction()
