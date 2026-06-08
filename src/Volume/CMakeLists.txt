# Volume layer - encryption algorithms, volume management, key derivation
# On Windows, Volume sources are compiled inline in Mount/Format targets.

if(NOT UNIX)
    add_library(veracrypt_volume INTERFACE)
    target_link_libraries(veracrypt_volume INTERFACE veracrypt_crypto veracrypt_common veracrypt_platform)
    return()
endif()

set(VOLUME_SOURCES
    Cipher.cpp
    EncryptionAlgorithm.cpp
    EncryptionMode.cpp
    EncryptionModeXTS.cpp
    EncryptionTest.cpp
    EncryptionThreadPool.cpp
    Hash.cpp
    Keyfile.cpp
    Pkcs5Kdf.cpp
    Volume.cpp
    VolumeException.cpp
    VolumeHeader.cpp
    VolumeInfo.cpp
    VolumeLayout.cpp
    VolumePassword.cpp
    VolumePasswordCache.cpp
)

if(VERACRYPT_WOLFCRYPT)
    list(FILTER VOLUME_SOURCES EXCLUDE REGEX "EncryptionModeXTS\\.cpp$")
    list(APPEND VOLUME_SOURCES EncryptionModeWolfCryptXTS.cpp)
endif()

add_library(veracrypt_volume STATIC ${VOLUME_SOURCES})
veracrypt_set_base_defines(veracrypt_volume)
veracrypt_set_warnings(veracrypt_volume)

target_link_libraries(veracrypt_volume PUBLIC
    veracrypt_crypto
    veracrypt_common
    veracrypt_platform
)

if(VERACRYPT_WOLFCRYPT)
    target_link_libraries(veracrypt_volume PUBLIC ${WOLFSSL_LIBRARY})
endif()

# Include Crypto directory for internal headers
target_include_directories(veracrypt_volume PRIVATE
    ${CMAKE_SOURCE_DIR}/src/Crypto
    ${CMAKE_SOURCE_DIR}/src/Crypto/Argon2/include
    ${CMAKE_SOURCE_DIR}/src/Common
)
