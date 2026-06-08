# FUSE driver (Unix only)

set(FUSE_SOURCES
    FuseService.cpp
)

add_library(veracrypt_fuse STATIC ${FUSE_SOURCES})
veracrypt_set_base_defines(veracrypt_fuse)
veracrypt_set_warnings(veracrypt_fuse)

target_link_libraries(veracrypt_fuse PUBLIC
    veracrypt_core
    veracrypt_volume
    PkgConfig::FUSE
)

target_compile_definitions(veracrypt_fuse PRIVATE
    VC_FUSE_VERSION=${FUSE_VERSION}
)

target_include_directories(veracrypt_fuse PRIVATE
    ${FUSE_INCLUDE_DIRS}
)
