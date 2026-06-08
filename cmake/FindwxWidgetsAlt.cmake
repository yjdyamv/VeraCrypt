# ============================================================================
# FindwxWidgetsAlt.cmake - detect wxWidgets or build from source
#
# Usage:
#   find_package(wxWidgetsAlt REQUIRED)
#
# Options:
#   VERACRYPT_WX_STATIC    - Statically link wxWidgets
#   VERACRYPT_WX_SOURCE    - Build wxWidgets from source (ExternalProject)
#
# Provides:
#   WX_LIBS        - wxWidgets libraries
#   WX_CXXFLAGS    - wxWidgets compile flags
#   WX_CONFIG      - wx-config path
# ============================================================================

option(VERACRYPT_WX_STATIC "Statically link wxWidgets" OFF)
option(VERACRYPT_WX_SOURCE "Build wxWidgets from source" OFF)

if(VERACRYPT_WX_SOURCE)
    # Not implemented yet - placeholder for Phase 3
    message(WARNING "VERACRYPT_WX_SOURCE not yet implemented, trying system wxWidgets")
endif()

if(VERACRYPT_NOGUI)
    set(_wx_components base)
else()
    set(_wx_components adv core base)
endif()

if(VERACRYPT_WX_STATIC)
    set(_wx_static ON)
else()
    set(_wx_static OFF)
endif()

find_package(wxWidgets COMPONENTS ${_wx_components} QUIET)

if(NOT wxWidgets_FOUND)
    # Try to find via wx-config
    find_program(WX_CONFIG wx-config)

    if(WX_CONFIG)
        execute_process(
            COMMAND ${WX_CONFIG} --cxxflags
            OUTPUT_VARIABLE WX_CXXFLAGS
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        execute_process(
            COMMAND ${WX_CONFIG} --libs ${_wx_components}
            OUTPUT_VARIABLE WX_LIBS
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        separate_arguments(WX_CXXFLAGS)
        separate_arguments(WX_LIBS)

        add_library(wx INTERFACE)
        target_compile_options(wx INTERFACE ${WX_CXXFLAGS})
        target_link_libraries(wx INTERFACE ${WX_LIBS})

        set(wxWidgets_FOUND TRUE)
        set(wxWidgets_LIBRARIES ${WX_LIBS})
        message(STATUS "Found wxWidgets via wx-config: ${WX_CONFIG}")
    else()
        message(FATAL_ERROR
            "wxWidgets not found. Install it or set VERACRYPT_WX_SOURCE=ON to build from source.")
    endif()
endif()

if(wxWidgets_FOUND)
    message(STATUS "wxWidgets: ${wxWidgets_INCLUDE_DIRS}")
endif()
