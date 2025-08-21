cmake_minimum_required(VERSION 3.30)
project(MotionDesk LANGUAGES CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_OBJCXX_STANDARD 23)

find_library(FOUNDATION Foundation REQUIRED)
find_library(APPKIT AppKit REQUIRED)
find_library(AVFOUNDATION AVFoundation REQUIRED)
find_library(COREGRAPHICS CoreGraphics REQUIRED)
find_library(IMAGEIO ImageIO REQUIRED)
find_library(IOKIT IOKit REQUIRED)
find_library(COREMEDIA CoreMedia REQUIRED)
find_library(UNIFORMTYPEIDENTIFIERS UniformTypeIdentifiers REQUIRED)
find_library(SERVICE_MANAGEMENT ServiceManagement REQUIRED)
find_library(USER_NOTIFICATIONS UserNotifications REQUIRED)

set(SOURCES
        src/main.mm
        src/PowerMonitor.mm
        src/AudioController.mm
        src/WallpaperEngine.mm
        src/MenuBarBridge.mm
        bridge/MotionDeskBridge.mm
        src/Types.mm
)

add_executable(MotionDesk ${SOURCES})

target_include_directories(MotionDesk PRIVATE src)

target_link_libraries(MotionDesk
        ${FOUNDATION}
        ${APPKIT}
        ${AVFOUNDATION}
        ${COREGRAPHICS}
        ${IMAGEIO}
        ${IOKIT}
        ${COREMEDIA}
        ${UNIFORMTYPEIDENTIFIERS}
        ${SERVICE_MANAGEMENT}
        ${USER_NOTIFICATIONS}
)

set_target_properties(MotionDesk PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/resources/Info.plist
        MACOSX_BUNDLE_ICON_FILE AppIcon
        LINKER_LANGUAGE CXX
)

target_sources(MotionDesk PRIVATE resources/AppIcon.icns)

set_source_files_properties(resources/AppIcon.icns PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources")
