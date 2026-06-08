# ============================================================================
# VeraCrypt compiler warnings configuration
# ============================================================================

function(veracrypt_set_warnings TARGET)
    if(MSVC)
        target_compile_options(${TARGET} PRIVATE
            /W3
            /wd4995   # name was marked as #pragma deprecated
            /wd4996   # deprecated function
        )
    else()
        target_compile_options(${TARGET} PRIVATE
            -Wall
            -Wno-unused-parameter
            $<$<COMPILE_LANGUAGE:CXX>:-Wno-unused-function>
            $<$<COMPILE_LANGUAGE:CXX>:-Wno-unused-variable>
        )
    endif()
endfunction()
