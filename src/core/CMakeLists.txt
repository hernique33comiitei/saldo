# saldocore: the in-process "backend" shared by the app (desktop + Android) and
# the Plasma widget. It is a shared library with a QML module on top; the
# widget loads it through the installed QML plugin (saldocoreplugin).

include(GenerateExportHeader)

set(SALDO_CORE_URI org.saldo.core)
set(SALDO_CORE_QML_DIR ${CMAKE_BINARY_DIR}/qml/org/saldo/core)

qt_add_library(saldocore SHARED)
if(NOT ANDROID)
    # APKs only accept unversioned libraries (libsaldocore.so).
    set_target_properties(saldocore PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR})
endif()

set(SALDO_CORE_QML_FILES
    qml/MoneyLabel.qml
    qml/LimitBar.qml
    qml/LimitDonut.qml
    qml/CategoryDonut.qml
    qml/CashflowChart.qml
    qml/BalanceChart.qml
    qml/TransactionContent.qml
    qml/CardContent.qml
    qml/SummaryRow.qml
    qml/chartscale.js
)
# Serve the QML files from the module root so they see the module's C++ types.
foreach(_file ${SALDO_CORE_QML_FILES})
    get_filename_component(_name ${_file} NAME)
    set_source_files_properties(${_file} PROPERTIES QT_RESOURCE_ALIAS ${_name})
endforeach()

qt_add_qml_module(saldocore
    URI ${SALDO_CORE_URI}
    VERSION 1.0
    OUTPUT_DIRECTORY ${SALDO_CORE_QML_DIR}
    PLUGIN_TARGET saldocoreplugin
    DEPENDENCIES QtQuick
    SOURCES
        logging.h logging.cpp
        paths.h paths.cpp
        records.h
        pluggyparser.h pluggyparser.cpp
        categories.h categories.cpp
        money.h money.cpp
        config.h config.cpp
        secretstore.h secretstore.cpp
        credentials.h credentials.cpp
        pluggyclient.h pluggyclient.cpp
        database.h database.cpp
        demodata.h demodata.cpp
        syncmanager.h syncmanager.cpp
        cardtotals.h cardtotals.cpp
        cardbills.h cardbills.cpp
        financesummary.h financesummary.cpp
        launcher.h launcher.cpp
        models/rowlistmodel.h models/rowlistmodel.cpp
        models/accountsmodel.h models/accountsmodel.cpp
        models/transactionsmodel.h models/transactionsmodel.cpp
        models/categoryspendmodel.h models/categoryspendmodel.cpp
        models/cashflowmodel.h models/cashflowmodel.cpp
        models/balancehistorymodel.h models/balancehistorymodel.cpp
        models/billsmodel.h models/billsmodel.cpp
        models/investmentsmodel.h models/investmentsmodel.cpp
        models/itemsmodel.h models/itemsmodel.cpp
    QML_FILES ${SALDO_CORE_QML_FILES}
)

generate_export_header(saldocore BASE_NAME saldocore)

# Bytecode only: qmlcachegen's C++ (AOT) output uses Qt private API, which would
# pin the packages to one exact Qt minor version (Qt_6.x_PRIVATE_API).
set_target_properties(saldocore PROPERTIES QT_QMLCACHEGEN_ARGUMENTS "--only-bytecode")

# KDECMakeSettings drops the "lib" prefix of modules, but the QML engine looks
# for lib<name>.so when it loads the plugin listed in qmldir.
if(UNIX AND NOT APPLE)
    set_target_properties(saldocoreplugin PROPERTIES PREFIX "lib")
endif()

target_include_directories(saldocore PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/models
    ${CMAKE_CURRENT_BINARY_DIR})

target_compile_definitions(saldocore PRIVATE
    TRANSLATION_DOMAIN="saldo"
    SALDO_APP_ID="${SALDO_APP_ID}"
    SALDO_VERSION="${PROJECT_VERSION}"
    SALDO_INSTALL_BINDIR="${KDE_INSTALL_FULL_BINDIR}")

target_link_libraries(saldocore
    PUBLIC
        Qt6::Core
        Qt6::Qml
        Qt6::Quick
    PRIVATE
        Qt6::Network
        Qt6::Sql
        Qt6::Concurrent
        KF6::I18n)

if(SALDO_USE_QTKEYCHAIN)
    target_compile_definitions(saldocore PRIVATE SALDO_USE_QTKEYCHAIN)
    target_link_libraries(saldocore PRIVATE Qt6Keychain::Qt6Keychain)
endif()

install(TARGETS saldocore ${KDE_INSTALL_TARGETS_DEFAULT_ARGS} LIBRARY NAMELINK_SKIP)

# Installed everywhere: the widget loads it from here, and on Android
# androiddeployqt resolves the QML imports from the installed tree.
set(_qml_dest ${KDE_INSTALL_QMLDIR}/org/saldo/core)
install(TARGETS saldocoreplugin LIBRARY DESTINATION ${_qml_dest})
install(FILES ${SALDO_CORE_QML_DIR}/qmldir ${SALDO_CORE_QML_DIR}/saldocore.qmltypes DESTINATION ${_qml_dest})
# The plugin lives deep inside the QML dir; for non-system prefixes such as
# ~/.local, point it at libsaldocore (distro packages need no RPATH).
if(NOT ANDROID AND NOT KDE_INSTALL_FULL_LIBDIR IN_LIST CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES)
    file(RELATIVE_PATH _plugin_to_lib "${KDE_INSTALL_FULL_QMLDIR}/org/saldo/core" "${KDE_INSTALL_FULL_LIBDIR}")
    set_target_properties(saldocoreplugin PROPERTIES INSTALL_RPATH "$ORIGIN/${_plugin_to_lib}")
endif()
