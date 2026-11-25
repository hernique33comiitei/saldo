// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

Kirigami.ScrollablePage {
    id: page

    // Phones: a large bold title in the header (PhoneTitle), and the View
    // colors, which the header, the tabs and the drawer share there (list
    // pages took them and the others the Window ones: two greys).
    Component.onCompleted: {
        if (Kirigami.Settings.isMobile) {
            titleDelegate = phoneTitle;
            Kirigami.Theme.colorSet = Kirigami.Theme.View;
        }
    }
    Component {
        id: phoneTitle
        PhoneTitle {
            text: page.title
        }
    }

    property string testMessage
    property bool testOk: false
    property string itemMessage
    property bool itemOk: false

    // "Name / description ........ [control]": one setting per row. On a
    // narrow card the control goes under the text instead of squeezing it.
    component SettingRow: GridLayout {
        id: row

        property string text
        property string description
        default property alias controls: controlRow.data
        readonly property bool stacked: width < Kirigami.Units.gridUnit * 20

        Layout.fillWidth: true
        columns: stacked ? 1 : 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QQC2.Label {
                Layout.fillWidth: true
                text: row.text
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: row.description.length > 0
                text: row.description
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
        RowLayout {
            id: controlRow
            Layout.alignment: row.stacked ? Qt.AlignLeft : (Qt.AlignRight | Qt.AlignVCenter)
            spacing: Kirigami.Units.smallSpacing
        }
    }

    // Small explanatory text under a group of controls.
    component Hint: QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    // Result of an action (test, add), green or red.
    component Feedback: QQC2.Label {
        property bool ok: false
        Layout.fillWidth: true
        visible: text.length > 0
        wrapMode: Text.Wrap
        color: ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
    }

    title: i18n("Settings")

    actions: [
        Kirigami.Action {
            text: i18n("Setup Guide")
            icon.name: "help-contents"
            onTriggered: applicationWindow().showPage("setup")
        }
    ]

    header: ColumnLayout {
        spacing: 0
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            position: Kirigami.InlineMessage.Header
            type: Kirigami.MessageType.Information
            visible: !Credentials.configured || Config.itemIds.length === 0
            text: i18n("Not connected yet. The setup guide walks you through Meu Pluggy step by step.")
            actions: [
                Kirigami.Action {
                    text: i18n("Open Setup Guide")
                    icon.name: "go-next-symbolic"
                    onTriggered: applicationWindow().showPage("setup")
                }
            ]
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            position: Kirigami.InlineMessage.Header
            type: Kirigami.MessageType.Warning
            visible: !Credentials.keyringAvailable
            text: Credentials.keyringUnavailableReason
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            position: Kirigami.InlineMessage.Header
            type: Kirigami.MessageType.Error
            visible: Credentials.error.length > 0
            text: Credentials.error
        }
    }

    Connections {
        target: SyncManager
        function onConnectionTested(ok, message) {
            page.testOk = ok;
            page.testMessage = message;
        }
        function onItemValidated(itemId, ok, message) {
            page.itemOk = ok;
            page.itemMessage = ok ? message : i18n("%1: %2", itemId.substring(0, 8), message);
        }
    }

    Connections {
        target: Credentials
        function onSaved() {
            secretField.text = "";
            page.testOk = true;
            page.testMessage = i18n("Credentials saved in the system keyring.");
        }
        function onCleared() {
            clientIdField.text = "";
            page.testOk = true;
            page.testMessage = i18n("Credentials removed.");
        }
    }

    // Two columns on wide windows, like the overview; one on narrow ones.
    GridLayout {
        columns: page.width > Kirigami.Units.gridUnit * 55 ? 2 : 1
        columnSpacing: Kirigami.Units.gridUnit
        rowSpacing: Kirigami.Units.gridUnit

        // Account: credentials and connections.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.gridUnit

            SectionCard {
                id: credentialsCard
                Layout.fillWidth: true
                title: i18n("Meu Pluggy credentials")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        text: i18n("Client ID")
                    }
                    QQC2.TextField {
                        id: clientIdField
                        Layout.fillWidth: true
                        text: Credentials.clientId
                        placeholderText: "00000000-0000-0000-0000-000000000000"
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        text: i18n("Client Secret")
                    }
                    Kirigami.PasswordField {
                        id: secretField
                        Layout.fillWidth: true
                        placeholderText: Credentials.configured ? i18n("Stored in the system keyring") : "pluggy_sk_…"
                    }
                }

                // One row with "Remove" on the right when everything fits the
                // card; otherwise "Remove" goes to a second row. Buttons keep
                // their width in a layout, so a single row would push the card
                // wider than a narrow window.
                GridLayout {
                    id: credentialButtons
                    readonly property bool oneRow: credentialsCard.width - credentialsCard.leftPadding - credentialsCard.rightPadding
                                                   >= saveButton.implicitWidth + testButton.implicitWidth + credentialsBusy.implicitWidth
                                                      + removeButton.implicitWidth + columnSpacing * 3 + Kirigami.Units.gridUnit
                    Layout.fillWidth: true
                    columns: oneRow ? 4 : 3
                    columnSpacing: Kirigami.Units.smallSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        id: saveButton
                        text: i18n("Save")
                        icon.name: "document-save"
                        enabled: !Credentials.busy && clientIdField.text.length > 0 && (secretField.text.length > 0 || Credentials.configured)
                        onClicked: Credentials.save(clientIdField.text, secretField.text)
                    }
                    QQC2.Button {
                        id: testButton
                        text: i18n("Test Connection")
                        icon.name: "network-connect"
                        enabled: !SyncManager.testing && clientIdField.text.length > 0 && (secretField.text.length > 0 || Credentials.configured)
                        onClicked: {
                            page.testMessage = "";
                            SyncManager.testConnection(clientIdField.text, secretField.text);
                        }
                    }
                    // Fills the rest of the row (pushing "Remove" right); stays in
                    // the layout while idle so the cells do not shift.
                    Item {
                        Layout.fillWidth: true
                        implicitWidth: credentialsBusy.implicitWidth
                        implicitHeight: credentialsBusy.implicitHeight
                        QQC2.BusyIndicator {
                            id: credentialsBusy
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            running: SyncManager.testing || Credentials.busy
                            opacity: running ? 1 : 0
                        }
                    }
                    QQC2.Button {
                        id: removeButton
                        Layout.columnSpan: credentialButtons.oneRow ? 1 : 3
                        Layout.alignment: credentialButtons.oneRow ? Qt.AlignRight : Qt.AlignLeft
                        visible: Credentials.configured
                        text: i18n("Remove Credentials")
                        icon.name: "edit-delete"
                        enabled: !Credentials.busy
                        onClicked: removeDialog.open()
                    }
                }

                Feedback {
                    text: page.testMessage
                    ok: page.testOk
                }
            }

            SectionCard {
                Layout.fillWidth: true
                title: i18n("Connections")

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: items.count === 0
                    text: i18n("None yet")
                    opacity: 0.7
                }

                Repeater {
                    model: ItemsModel {
                        id: items
                    }
                    delegate: ColumnLayout {
                        id: itemRow
                        required property var model
                        required property int index

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Separator {
                            Layout.fillWidth: true
                            visible: itemRow.index > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignTop
                                source: itemRow.model.status.length === 0 ? "data-information" : itemRow.model.healthy ? "emblem-ok-symbolic" : "data-warning"
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: itemRow.model.connectorName
                                    elide: Text.ElideRight
                                    font.weight: Font.DemiBold
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    visible: itemRow.model.accountsSummary.length > 0
                                    text: itemRow.model.accountsSummary
                                    wrapMode: Text.Wrap
                                    font: Kirigami.Theme.smallFont
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: [
                                        itemRow.model.status === "UPDATED" ? "" : itemRow.model.statusLabel,
                                        itemRow.model.lastUpdatedLabel ? i18n("updated %1", itemRow.model.lastUpdatedLabel) : "",
                                        itemRow.model.consentLabel ? i18n("authorized until %1", itemRow.model.consentLabel) : ""
                                    ].filter(part => part.length > 0).join(" · ")
                                    wrapMode: Text.Wrap
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                }
                                Kirigami.SelectableLabel {
                                    Layout.fillWidth: true
                                    // Breaks anywhere so a long ID never widens the card.
                                    wrapMode: Text.WrapAnywhere
                                    text: itemRow.model.itemId
                                    font.family: Kirigami.Theme.fixedWidthFont.family
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    opacity: 0.6
                                }
                            }
                            QQC2.ToolButton {
                                Layout.alignment: Qt.AlignTop
                                icon.name: "document-edit"
                                text: i18n("Name this connection")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                                onClicked: renameDialog.openFor(itemRow.model.itemId, itemRow.model.nickname, itemRow.model.accountsSummary)
                            }
                            QQC2.ToolButton {
                                Layout.alignment: Qt.AlignTop
                                icon.name: "edit-delete"
                                text: i18n("Remove connection")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                                onClicked: Config.removeItemId(itemRow.model.itemId)
                            }
                        }
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    enabled: Config.itemIds.length < 5

                    QQC2.Label {
                        text: i18n("Add a connection")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.TextField {
                            id: newItemField
                            Layout.fillWidth: true
                            placeholderText: i18n("Item ID from the Pluggy dashboard")
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            onAccepted: if (addButton.enabled) addButton.clicked()
                        }
                        QQC2.Button {
                            id: addButton
                            text: i18n("Add")
                            icon.name: "list-add"
                            enabled: newItemField.text.trim().length > 0
                            onClicked: {
                                const ids = Config.findIds(newItemField.text);
                                const errors = ids.length === 0 ? [i18n("No item ID found. It looks like 3fa85f64-5717-4562-b3fc-2c963f66afa6.")] : [];
                                for (const id of ids) {
                                    const error = Config.addItemId(id);
                                    if (error.length > 0) {
                                        errors.push(error);
                                    } else if (Credentials.configured) {
                                        SyncManager.validateItem(id);
                                    }
                                }
                                page.itemOk = errors.length === 0;
                                page.itemMessage = errors.join("\n");
                                if (errors.length === 0) {
                                    newItemField.text = "";
                                }
                            }
                        }
                    }
                }

                Feedback {
                    text: page.itemMessage
                    ok: page.itemOk
                }

                Hint {
                    text: i18n("Each bank you authorize in Meu Pluggy is a separate connection (up to 5). Authorizations last one year; renewing one may give it a new item ID.")
                }
            }

        }

        // Behavior and local data.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.gridUnit

            SectionCard {
                Layout.fillWidth: true
                title: i18n("Sync")

                SettingRow {
                    text: i18n("Transaction history")
                    description: i18n("How far back the first sync goes.")
                    QQC2.SpinBox {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                        from: 1
                        to: 24
                        value: Config.historyMonths
                        textFromValue: (value, locale) => i18np("%1 month", "%1 months", value)
                        onValueModified: Config.historyMonths = value
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                SettingRow {
                    text: i18n("Check for new data every")
                    description: i18n("Meu Pluggy refreshes your banks once a day on its own; checking more often only picks up that daily update sooner.")
                    QQC2.SpinBox {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                        from: 15
                        to: 24 * 60
                        stepSize: 15
                        value: Config.refreshMinutes
                        textFromValue: (value, locale) => value % 60 === 0 ? i18np("%1 hour", "%1 hours", value / 60) : i18np("%1 minute", "%1 minutes", value)
                        onValueModified: Config.refreshMinutes = value
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                SettingRow {
                    text: i18n("Last sync")
                    description: Money.relativeTime(SyncManager.lastSyncAt)
                    QQC2.BusyIndicator {
                        visible: SyncManager.running
                        running: visible
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    }
                    QQC2.Button {
                        text: i18n("Sync Now")
                        icon.name: "view-refresh"
                        enabled: Credentials.configured && !SyncManager.running && Config.itemIds.length > 0
                        onClicked: SyncManager.sync()
                    }
                }
            }

            SectionCard {
                Layout.fillWidth: true
                title: i18n("Privacy")

                SettingRow {
                    text: i18n("Hide values")
                    description: i18n("Hides the amounts in the app and in the widget.")
                    QQC2.Switch {
                        checked: Config.privacyMode
                        onToggled: Config.privacyMode = checked
                        Accessible.name: i18n("Hide values")
                    }
                }
            }

            SectionCard {
                Layout.fillWidth: true
                title: i18n("Language")

                SettingRow {
                    text: i18n("App language")
                    description: i18n("Takes effect the next time Saldo starts. The Plasma widget follows the system language.")
                    QQC2.ComboBox {
                        // Values of Config.language. Language names are written in
                        // their own language, as language pickers do.
                        readonly property var codes: ["", "en", "pt_BR"]
                        model: [i18n("System default"), "English", "Português (Brasil)"]
                        currentIndex: Math.max(0, codes.indexOf(Config.language))
                        onActivated: {
                            Config.language = codes[currentIndex];
                            applicationWindow().showPassiveNotification(i18n("Restart Saldo to apply the language change."), "long");
                        }
                    }
                }
            }

            SectionCard {
                Layout.fillWidth: true
                title: i18n("Appearance")

                SettingRow {
                    text: i18n("Theme")
                    description: Qt.platform.os === "android"
                                 ? i18n("“System default” follows the phone's dark mode.")
                                 : i18n("“System default” follows the system: Plasma's colors, or the desktop's dark mode elsewhere. The Plasma widget follows Plasma.")
                    QQC2.ComboBox {
                        // Values of Config.theme; applied right away (colorscheme.cpp).
                        readonly property var codes: ["", "light", "dark"]
                        model: [i18n("System default"), i18nc("color theme", "Light"), i18nc("color theme", "Dark")]
                        currentIndex: Math.max(0, codes.indexOf(Config.theme))
                        onActivated: Config.theme = codes[currentIndex]
                    }
                }
            }

            SectionCard {
                Layout.fillWidth: true
                title: i18n("Local data")

                SettingRow {
                    text: i18n("Raw data")
                    description: i18n("What Pluggy returned for each account, to check amounts and signs.")
                    QQC2.Button {
                        text: i18n("Raw Data…")
                        icon.name: "documentinfo"
                        onClicked: applicationWindow().pageStack.push(rawDataComponent)
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                SettingRow {
                    text: i18n("Local cache")
                    description: i18n("Deletes the downloaded data; the next sync fetches it again. Settings, connection names, transfer choices and balance history are kept.")
                    QQC2.Button {
                        text: i18n("Clear Local Cache")
                        icon.name: "edit-clear-history"
                        enabled: !SyncManager.running
                        onClicked: SyncManager.clearCache()
                    }
                }
            }
        }
    }

    RenameConnectionDialog {
        id: renameDialog
    }

    Kirigami.PromptDialog {
        id: removeDialog
        title: i18n("Remove Credentials?")
        subtitle: i18n("The Client ID and Client Secret will be deleted from the system keyring. Cached data stays until you clear it.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        // Our own texts: Qt's follow the system language (see RenameConnectionDialog).
        onAboutToShow: {
            standardButton(Kirigami.Dialog.Ok).text = i18n("OK");
            standardButton(Kirigami.Dialog.Cancel).text = i18n("Cancel");
        }
        onAccepted: Credentials.clear()
    }

    Component {
        id: rawDataComponent
        RawDataPage {}
    }
}
