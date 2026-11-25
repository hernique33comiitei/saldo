# Saldo's design system: QML module org.saldo.ui, its tokens and the
# components the pages use (`import org.saldo.ui as UI`). Static, linked into
# the app (main.cpp imports its plugin), so nothing more to install or package.
set(SALDO_UI_QML_FILES
    Tokens.qml
    Platform.qml
    Card.qml
    IconBadge.qml
    Chip.qml
    TabBar.qml
    DrawerItem.qml
    PageTitle.qml
    SectionHeader.qml
    SummaryHeader.qml
    FieldBackground.qml
    SheetBackground.qml
    SheetStyle.qml
    TextField.qml
    TextArea.qml
    PasswordField.qml
    SearchField.qml
    Button.qml
    IconButton.qml
    Switch.qml
    Select.qml
    NumberField.qml
    Banner.qml
    EmptyState.qml
    BusyIndicator.qml
    Sheet.qml
    ConfirmSheet.qml
)
set_source_files_properties(Tokens.qml Platform.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(saldoui
    STATIC
    URI org.saldo.ui
    VERSION 1.0
    # Under its URI path, so qmllint and the engine find it from the build tree.
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/org/saldo/ui
    QML_FILES ${SALDO_UI_QML_FILES}
)

# Bytecode only (see src/core/CMakeLists.txt): no Qt private API dependency.
set_target_properties(saldoui PROPERTIES QT_QMLCACHEGEN_ARGUMENTS "--only-bytecode")
