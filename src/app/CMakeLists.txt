qt_add_executable(saldo main.cpp colorscheme.cpp frameworkcatalogs.cpp)

set(SALDO_APP_QML_FILES
    Main.qml
    pages/OverviewPage.qml
    pages/AccountsPage.qml
    pages/CardsPage.qml
    pages/CardDetailPage.qml
    pages/TransactionsPage.qml
    pages/InvestmentsPage.qml
    pages/SettingsPage.qml
    pages/RawDataPage.qml
    pages/SetupPage.qml
    pages/AboutPage.qml
    components/StatCard.qml
    components/SectionCard.qml
    components/RefreshablePage.qml
    components/SyncBanner.qml
    components/SetupStep.qml
    components/SetupInstructions.qml
    components/RenameConnectionDialog.qml
    components/TransactionDialog.qml
)
# Serve every QML file from the module root so they see each other.
foreach(_file ${SALDO_APP_QML_FILES})
    get_filename_component(_name ${_file} NAME)
    set_source_files_properties(${_file} PROPERTIES QT_RESOURCE_ALIAS ${_name})
endforeach()

qt_add_qml_module(saldo
    URI org.saldo
    VERSION 1.0
    QML_FILES ${SALDO_APP_QML_FILES}
    SOURCES about.h about.cpp
)

# Bytecode only (see src/core/CMakeLists.txt): no Qt private API dependency.
set_target_properties(saldo PROPERTIES QT_QMLCACHEGEN_ARGUMENTS "--only-bytecode")

# The app icon is embedded so the window/drawer never show a stale themed copy.
qt_add_resources(saldo "saldo_icons"
    PREFIX "/icons"
    BASE ${CMAKE_SOURCE_DIR}/data/icons
    FILES ${CMAKE_SOURCE_DIR}/data/icons/saldo.svg ${CMAKE_SOURCE_DIR}/data/icons/saldo-symbolic.svg)

target_compile_definitions(saldo PRIVATE
    SALDO_VERSION="${PROJECT_VERSION}"
    SALDO_APP_ID="${SALDO_APP_ID}"
    SALDO_WEBSITE="${SALDO_WEBSITE}"
    TRANSLATION_DOMAIN="saldo")

target_link_libraries(saldo PRIVATE
    saldocore
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    KF6::I18n
    KF6::I18nQml
    KF6::CoreAddons
    KF6::ColorScheme)

if(ANDROID)
    # No icon theme on Android: bundle the Breeze icons the UI uses.
    kirigami_package_breeze_icons(ICONS
        amarok_cart_view-symbolic bookmarks-symbolic car configure data-information data-warning
        dialog-ok-apply document-edit document-save documentinfo edit-clear-history edit-copy edit-delete edit-paste edit-find edit-undo
        emblem-ok-symbolic exchange-positions firewall-applet-shields_up-symbolic food globe go-home-symbolic
        go-next-symbolic help-about help-contents help-donate input-gamepad-symbolic internet-services-symbolic list-add list-remove love mail-sent
        network-connect open-link-symbolic phone-symbolic tag-symbolic taxes-finances tools-report-bug video-symbolic view-bank
        view-financial-account-checking view-financial-account-credit-card
        view-financial-account-credit-card-symbolic view-financial-account-investment
        view-financial-account-savings
        view-financial-category-income view-financial-list view-hidden view-pim-tasks view-refresh
        view-statistics view-visible wallet-open)
    target_link_libraries(saldo PRIVATE Qt6::Svg OpenSSL::SSL)
    # create-apk target (used by KDE Craft): manifest, gradle and icon from android/.
    ecm_add_android_apk(saldo ANDROID_DIR ${CMAKE_SOURCE_DIR}/android)
else()
    target_link_libraries(saldo PRIVATE Qt6::Widgets)
    # Qt is shared on desktop: QML plugins load at runtime, nothing to link.
    set_target_properties(saldo PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN TRUE)
endif()

install(TARGETS saldo ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
