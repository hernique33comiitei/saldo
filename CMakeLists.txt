cmake_minimum_required(VERSION 3.28)

project(saldo VERSION 0.0.10 LANGUAGES CXX)

set(SALDO_APP_ID "io.github.hernique33comiitei.Saldo")
set(SALDO_PLASMOID_ID "io.github.hernique33comiitei.saldo")
set(SALDO_WEBSITE "https://github.com/hernique33comiitei/saldo")

set(QT_MIN_VERSION "6.8.0")
# KLocalization::setupLocalizedContext() (KF6::I18nQml) needs KF 6.8.
set(KF_MIN_VERSION "6.8.0")

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)
include(ECMAddAndroidApk)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(ANDROID)
    set(_saldo_desktop OFF)
else()
    set(_saldo_desktop ON)
endif()

option(BUILD_PLASMOID "Build and install the Plasma widget" ${_saldo_desktop})
option(SALDO_USE_QTKEYCHAIN "Store secrets with QtKeychain (required on Android) instead of secret-tool" ${ANDROID})

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network Sql Concurrent)
if(ANDROID)
    # The APK comes from ECM's create-apk target (what KDE Craft runs); keep the
    # APK that qt_add_executable would build on its own out of the default build.
    set(QT_NO_GLOBAL_APK_TARGET_PART_OF_ALL ON)
    # SVG icons (Kirigami) and HTTPS (Qt loads OpenSSL at runtime) must be bundled.
    find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Svg)
    find_package(OpenSSL REQUIRED)
else()
    find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Widgets)
endif()
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS Kirigami I18n CoreAddons)
# The app's light/dark theme (src/app/colorscheme.cpp). 6.13: Debian 13's
# (activateSchemeId, 6.19, is used when present).
find_package(KF6ColorScheme 6.13 REQUIRED)

if(SALDO_USE_QTKEYCHAIN)
    find_package(Qt6Keychain REQUIRED)
    set_package_properties(Qt6Keychain PROPERTIES TYPE REQUIRED PURPOSE "Secret storage (Android Keystore / Secret Service)")
endif()

# Runtime-only QML modules, checked so a missing one is reported at configure time.
find_package(KF6QuickCharts QUIET)
set_package_properties(KF6QuickCharts PROPERTIES TYPE RUNTIME PURPOSE "Charts (org.kde.quickcharts QML module)")

qt_standard_project_setup(REQUIRES 6.8)

add_subdirectory(src)

if(BUILD_PLASMOID)
    add_subdirectory(plasmoid)
endif()

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

include(SaldoTranslations)
saldo_install_translations(DOMAIN saldo PO_DIR ${CMAKE_CURRENT_SOURCE_DIR}/po)

if(NOT ANDROID)
    # ~/.local/bin is not always in the PATH of the Plasma session.
    if(CMAKE_INSTALL_PREFIX STREQUAL "/usr" OR CMAKE_INSTALL_PREFIX STREQUAL "/usr/local")
        set(SALDO_DESKTOP_EXEC saldo)
    else()
        set(SALDO_DESKTOP_EXEC "${KDE_INSTALL_FULL_BINDIR}/saldo")
    endif()
    configure_file(data/${SALDO_APP_ID}.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/${SALDO_APP_ID}.desktop @ONLY)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${SALDO_APP_ID}.desktop DESTINATION ${KDE_INSTALL_APPDIR})
    install(FILES data/${SALDO_APP_ID}.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
    install(FILES data/icons/saldo.svg data/icons/saldo-symbolic.svg DESTINATION ${KDE_INSTALL_ICONDIR}/hicolor/scalable/apps)
endif()


feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
