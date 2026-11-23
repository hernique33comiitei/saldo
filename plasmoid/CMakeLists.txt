# Plasma 6 widget: a QML-only package that imports the saldocore QML plugin.
set(_package_dest ${KDE_INSTALL_DATADIR}/plasma/plasmoids/${SALDO_PLASMOID_ID})

configure_file(package/metadata.json.in ${CMAKE_CURRENT_BINARY_DIR}/metadata.json @ONLY)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/metadata.json DESTINATION ${_package_dest})
install(DIRECTORY package/contents DESTINATION ${_package_dest})
