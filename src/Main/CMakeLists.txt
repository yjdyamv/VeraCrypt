# Main executable - GUI and CLI entry point

# -------------------------------------------------------------------
# Main sources
# -------------------------------------------------------------------
set(MAIN_SOURCES
    Application.cpp
    CommandLineInterface.cpp
    FavoriteVolume.cpp
    LanguageStrings.cpp
    StringFormatter.cpp
    TextUserInterface.cpp
    UserInterface.cpp
    UserPreferences.cpp
    Xml.cpp
    Unix/Main.cpp
    Resources.cpp
)

# GUI-specific sources
if(NOT VERACRYPT_NOGUI)
    list(APPEND MAIN_SOURCES
        FatalErrorHandler.cpp
        GraphicUserInterface.cpp
        VolumeHistory.cpp
        Forms/AboutDialog.cpp
        Forms/BenchmarkDialog.cpp
        Forms/ChangePasswordDialog.cpp
        Forms/DeviceSelectionDialog.cpp
        Forms/EncryptionOptionsWizardPage.cpp
        Forms/EncryptionTestDialog.cpp
        Forms/FavoriteVolumesDialog.cpp
        Forms/Forms.cpp
        Forms/InfoWizardPage.cpp
        Forms/KeyfileGeneratorDialog.cpp
        Forms/KeyfilesDialog.cpp
        Forms/KeyfilesPanel.cpp
        Forms/LegalNoticesDialog.cpp
        Forms/MainFrame.cpp
        Forms/MountOptionsDialog.cpp
        Forms/NewSecurityTokenKeyfileDialog.cpp
        Forms/PreferencesDialog.cpp
        Forms/ProgressWizardPage.cpp
        Forms/RandomPoolEnrichmentDialog.cpp
        Forms/SecurityTokenKeyfilesDialog.cpp
        Forms/SelectDirectoryWizardPage.cpp
        Forms/VolumePasswordPanel.cpp
        Forms/VolumePropertiesDialog.cpp
        Forms/VolumeCreationProgressWizardPage.cpp
        Forms/VolumeCreationWizard.cpp
        Forms/VolumeFormatOptionsWizardPage.cpp
        Forms/VolumeLocationWizardPage.cpp
        Forms/VolumePasswordWizardPage.cpp
        Forms/VolumePimWizardPage.cpp
        Forms/VolumeSizeWizardPage.cpp
        Forms/WaitDialog.cpp
        Forms/WizardFrame.cpp
    )

    if(APPLE)
        list(APPEND MAIN_SOURCES MacOSXSecureTextFieldHotkeys.cpp)
    endif()
endif()

# -------------------------------------------------------------------
# Resource embedding (XML, BMP, TXT -> .h)
# -------------------------------------------------------------------
set(RESOURCE_OUTPUTS "")
set(RESOURCE_FILES
    "${CMAKE_SOURCE_DIR}/License.txt"
    "${CMAKE_SOURCE_DIR}/src/Common/Language.xml"
)

if(NOT VERACRYPT_NOGUI)
    list(APPEND RESOURCE_FILES
        "${CMAKE_SOURCE_DIR}/src/Common/Textual_logo_96dpi.bmp"
        "${CMAKE_SOURCE_DIR}/src/Format/VeraCrypt_Wizard.bmp"
        "${CMAKE_SOURCE_DIR}/src/Mount/Drive_icon_96dpi.bmp"
        "${CMAKE_SOURCE_DIR}/src/Mount/Drive_icon_mask_96dpi.bmp"
        "${CMAKE_SOURCE_DIR}/src/Mount/Logo_96dpi.bmp"
    )
endif()

foreach(RES_FILE ${RESOURCE_FILES})
    get_filename_component(RES_NAME ${RES_FILE} NAME)
    set(RES_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${RES_NAME}.h")
    veracrypt_embed_resource(${RES_OUTPUT} ${RES_FILE})
    list(APPEND RESOURCE_OUTPUTS ${RES_OUTPUT})
endforeach()

# -------------------------------------------------------------------
# Create executable
# -------------------------------------------------------------------
add_executable(veracrypt ${MAIN_SOURCES} ${RESOURCE_OUTPUTS})

veracrypt_set_base_defines(veracrypt)
veracrypt_set_warnings(veracrypt)

target_link_libraries(veracrypt PRIVATE
    veracrypt_fuse
    veracrypt_core
    veracrypt_volume
    veracrypt_platform
    veracrypt_common
    PkgConfig::FUSE
)

target_include_directories(veracrypt PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)

# -------------------------------------------------------------------
# wxWidgets integration
# -------------------------------------------------------------------
if(NOT VERACRYPT_NOGUI)
    if(wxWidgets_FOUND)
        target_link_libraries(veracrypt PRIVATE ${wxWidgets_LIBRARIES})
        target_include_directories(veracrypt PRIVATE ${wxWidgets_INCLUDE_DIRS})
        target_compile_definitions(veracrypt PRIVATE ${wxWidgets_DEFINITIONS})
    elseif(WX_CONFIG)
        target_compile_options(veracrypt PRIVATE ${WX_CXXFLAGS})
        target_link_libraries(veracrypt PRIVATE ${WX_LIBS})
    endif()
endif()

# -------------------------------------------------------------------
# Platform-specific linker flags
# -------------------------------------------------------------------
if(LINUX)
    target_link_options(veracrypt PRIVATE -rdynamic)

    if(VERACRYPT_WX_STATIC)
        target_link_libraries(veracrypt PRIVATE dl)
    endif()

    # PCSC
    if(PCSC_FOUND)
        target_link_libraries(veracrypt PRIVATE PkgConfig::PCSC)
    endif()
elseif(APPLE)
    target_link_options(veracrypt PRIVATE
        -mmacosx-version-min=${VERACRYPT_OSX_TARGET}
        -Wl,-export_dynamic
    )
endif()

# -------------------------------------------------------------------
# Install
# -------------------------------------------------------------------
if(LINUX)
    install(TARGETS veracrypt RUNTIME DESTINATION bin)
elseif(APPLE)
    install(TARGETS veracrypt BUNDLE DESTINATION .)
endif()
