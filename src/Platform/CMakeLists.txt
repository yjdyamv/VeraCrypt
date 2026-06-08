# Platform abstraction layer

set(PLATFORM_SOURCES
    Buffer.cpp
    Exception.cpp
    Event.cpp
    FileCommon.cpp
    MemoryStream.cpp
    Memory.cpp
    PlatformTest.cpp
    Serializable.cpp
    Serializer.cpp
    SerializerFactory.cpp
    StringConverter.cpp
    TextReader.cpp
)

if(UNIX)
    list(APPEND PLATFORM_SOURCES
        Unix/Directory.cpp
        Unix/File.cpp
        Unix/FilesystemPath.cpp
        Unix/Mutex.cpp
        Unix/Pipe.cpp
        Unix/Poller.cpp
        Unix/Process.cpp
        Unix/SyncEvent.cpp
        Unix/SystemException.cpp
        Unix/SystemInfo.cpp
        Unix/SystemLog.cpp
        Unix/Thread.cpp
        Unix/Time.cpp
    )
endif()

if(WIN32)
    # Windows platform layer is compiled inline in Mount/Format targets.
    # This target is a stub; full Windows Platform implementation is Phase 7.
    add_library(veracrypt_platform INTERFACE)
    target_link_libraries(veracrypt_platform INTERFACE veracrypt_common)
    return()
endif()

add_library(veracrypt_platform STATIC ${PLATFORM_SOURCES})
veracrypt_set_base_defines(veracrypt_platform)
veracrypt_set_warnings(veracrypt_platform)
target_link_libraries(veracrypt_platform PUBLIC veracrypt_common)
if(UNIX)
    target_include_directories(veracrypt_platform PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Unix
    )
endif()

if(APPLE)
    enable_language(OBJC)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Unix/MacOSX/CoreMacOSX.cpp")
        set_source_files_properties(
            Unix/MacOSX/CoreMacOSX.cpp
            PROPERTIES LANGUAGE OBJC
        )
    endif()
endif()
