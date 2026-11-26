// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI
import org.saldo.core

// Guided setup of the Meu Pluggy connection, step by step. Labels in quotes are
// the exact names of buttons and sections in Pluggy's (Portuguese) dashboard.
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
        UI.PageTitle {
            text: page.title
        }
    }

    readonly property string meuPluggyUrl: "https://meu.pluggy.ai"
    readonly property string dashboardUrl: "https://dashboard.pluggy.ai"
    readonly property string guideUrl: "https://docs.pluggy.ai/pt/docs/guides/meu-pluggy-personal-use"

    readonly property bool step1Done: Config.setupStep >= 1 || Credentials.configured
    readonly property bool step2Done: Credentials.configured
    readonly property bool step3Done: Config.setupStep >= 3 || Config.itemIds.length > 0
    readonly property bool step4Done: Config.setupStep >= 4 && Config.itemIds.length > 0
    readonly property bool step5Done: FinanceSummary.hasData
    readonly property int firstIncomplete: !step1Done ? 1 : !step2Done ? 2 : !step3Done ? 3 : !step4Done ? 4 : 5
    // The user may reopen an earlier step by clicking its title.
    property int selectedStep: 0
    readonly property int openStep: selectedStep > 0 ? selectedStep : firstIncomplete

    property string credentialsMessage
    property bool credentialsOk: false
    property string itemMessage
    property bool itemOk: false

    function statusOf(number: int, done: bool): int {
        if (done) {
            return SetupStep.Done;
        }
        return number === firstIncomplete ? SetupStep.Current : SetupStep.Upcoming;
    }

    function advance(step: int) {
        if (Config.setupStep < step) {
            Config.setupStep = step;
        }
        selectedStep = 0;
    }

    function addItems(text: string) {
        const ids = Config.findIds(text);
        if (ids.length === 0) {
            itemOk = false;
            itemMessage = i18n("No item ID found. It looks like 3fa85f64-5717-4562-b3fc-2c963f66afa6.");
            return;
        }
        const errors = [];
        for (const id of ids) {
            const error = Config.addItemId(id);
            if (error.length > 0) {
                errors.push(error);
            } else {
                SyncManager.validateItem(id);
            }
        }
        itemField.text = "";
        itemOk = errors.length === 0;
        itemMessage = errors.length > 0 ? errors.join("\n") : i18n("Checking with Pluggy…");
    }

    title: i18n("Connect Meu Pluggy")

    actions: [
        Kirigami.Action {
            text: i18n("Pluggy Guide")
            icon.name: "help-contents"
            displayHint: Kirigami.Settings.isMobile ? Kirigami.DisplayHint.IconOnly : Kirigami.DisplayHint.NoPreference
            onTriggered: Qt.openUrlExternally(page.guideUrl)
        }
    ]

    Connections {
        target: SyncManager
        function onConnectionTested(ok: bool, message: string) {
            if (!ok) {
                page.credentialsOk = false;
                page.credentialsMessage = message;
                return;
            }
            Credentials.save(clientIdField.text, secretField.text);
        }
        function onItemValidated(itemId: string, ok: bool, message: string) {
            page.itemOk = ok;
            page.itemMessage = ok ? i18n("Found: %1", message) : i18n("%1: %2", itemId.substring(0, 8), message);
        }
    }

    Connections {
        target: Credentials
        function onSaved() {
            secretField.text = "";
            page.credentialsOk = true;
            page.credentialsMessage = i18n("Connected and saved in the system keyring.");
            page.selectedStep = 0;
        }
    }

    RenameConnectionDialog {
        id: renameDialog
    }

    ColumnLayout {
        spacing: 0

        // A readable column, centered on wide windows.
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 36
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                text: i18n("Saldo reads your banks through Meu Pluggy, Pluggy's free personal-use service. It takes about five minutes, mostly in your browser; keep this window open and come back after each step.")
                wrapMode: Text.Wrap
            }

            // 1 ─ Meu Pluggy account
            SetupStep {
                Layout.fillWidth: true
                number: 1
                title: i18n("Create your Meu Pluggy account")
                summary: i18n("Account created and banks connected at meu.pluggy.ai.")
                status: page.statusOf(1, page.step1Done)
                expanded: page.openStep === 1
                onHeaderClicked: page.selectedStep = 1

                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("Sign up at meu.pluggy.ai and connect your banks there. Each bank asks you to approve the access in its own app.")
                    wrapMode: Text.Wrap
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    UI.Button {
                        text: i18n("Open meu.pluggy.ai")
                        icon.name: "internet-services-symbolic"
                        onClicked: Qt.openUrlExternally(page.meuPluggyUrl)
                    }
                    UI.Button {
                        text: i18n("My Banks Are Connected")
                        icon.name: "go-next-symbolic"
                        onClicked: page.advance(1)
                    }
                }
            }

            // 2 ─ Client ID + Client Secret
            SetupStep {
                Layout.fillWidth: true
                number: 2
                title: i18n("Copy your application's credentials")
                summary: Credentials.configured ? i18n("Client ID %1… · secret stored in the keyring.", Credentials.clientId.substring(0, 8)) : ""
                status: page.statusOf(2, page.step2Done)
                expanded: page.openStep === 2
                onHeaderClicked: page.selectedStep = 2

                SetupInstructions {
                    Layout.fillWidth: true
                    steps: [
                        i18nc("Aplicações is a label in the Pluggy dashboard; keep it as is",
                              "Open the Pluggy dashboard with the same login and go to <b>“Aplicações”</b>."),
                        i18n("On your application (for example <i>Pluggy Demo App</i>), copy the <b>Client ID</b> with the copy button and paste it below."),
                        i18nc("Credenciais and Gerar novo secret are labels in the Pluggy dashboard; keep them as is",
                              "The <b>Client Secret</b> is shown only once, when it is created. If you don't have it, open the application's gear and, under <b>“Credenciais”</b>, click <b>“Gerar novo secret”</b>.")
                    ]
                }
                UI.Button {
                    text: i18n("Open the Pluggy Dashboard")
                    icon.name: "internet-services-symbolic"
                    onClicked: Qt.openUrlExternally(page.dashboardUrl)
                }

                // Labels above the fields (as in Settings), so the form fits a
                // narrow window next to the step rail.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: i18n("Client ID")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        UI.TextField {
                            id: clientIdField
                            Layout.fillWidth: true
                            text: Credentials.clientId
                            placeholderText: "00000000-0000-0000-0000-000000000000"
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            font.family: Kirigami.Theme.fixedWidthFont?.family ?? UI.Tokens.monospaceFamily
                            onEditingFinished: {
                                const ids = Config.findIds(text);
                                if (ids.length === 1 && ids[0] !== text) {
                                    text = ids[0];
                                }
                            }
                        }
                        UI.Button {
                            icon.name: "edit-paste"
                            text: i18n("Paste")
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: {
                                clientIdField.clear();
                                clientIdField.paste();
                                clientIdField.editingFinished();
                            }
                        }
                    }

                    QQC2.Label {
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        text: i18n("Client Secret")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        UI.PasswordField {
                            id: secretField
                            Layout.fillWidth: true
                            placeholderText: Credentials.configured ? i18n("Stored in the system keyring") : "pluggy_sk_…"
                            onAccepted: if (testButton.enabled) testButton.clicked()
                        }
                        UI.Button {
                            icon.name: "edit-paste"
                            text: i18n("Paste")
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: {
                                secretField.clear();
                                secretField.paste();
                                secretField.text = secretField.text.trim();
                            }
                        }
                    }

                    RowLayout {
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing
                        UI.Button {
                            id: testButton
                            text: i18n("Connect and Save")
                            icon.name: "network-connect"
                            enabled: !SyncManager.testing && !Credentials.busy && clientIdField.text.trim().length > 0
                                     && (secretField.text.trim().length > 0 || Credentials.configured)
                            onClicked: {
                                if (secretField.text.trim().length > 0 && secretField.text.trim() === clientIdField.text.trim()) {
                                    page.credentialsOk = false;
                                    page.credentialsMessage = i18n("The Client Secret is a different value from the Client ID.");
                                    return;
                                }
                                page.credentialsMessage = "";
                                SyncManager.testConnection(clientIdField.text, secretField.text);
                            }
                        }
                        UI.BusyIndicator {
                            visible: SyncManager.testing || Credentials.busy
                            running: visible
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: page.credentialsMessage.length > 0
                    text: page.credentialsMessage
                    wrapMode: Text.Wrap
                    color: page.credentialsOk ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("The secret goes to your system keyring, never to a file. Don't share it or post screenshots of it.")
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }

            // 3 ─ Connect the MeuPluggy connector in the demo
            SetupStep {
                Layout.fillWidth: true
                number: 3
                title: i18n("Connect Meu Pluggy to your application")
                summary: i18n("MeuPluggy connected through the dashboard demo.")
                status: page.statusOf(3, page.step3Done)
                expanded: page.openStep === 3
                onHeaderClicked: page.selectedStep = 3

                SetupInstructions {
                    Layout.fillWidth: true
                    steps: [
                        i18nc("Aplicações and Iniciar Demo are labels in the Pluggy dashboard; keep them as is",
                              "Back in <b>“Aplicações”</b>, press the <b>▶</b> button (<b>“Iniciar Demo”</b>) on your application."),
                        i18nc("Conectar Conta is a label in the Pluggy dashboard and MeuPluggy a connector name; keep them as is",
                              "Click <b>“Conectar Conta”</b> and search for <b>MeuPluggy</b>. Pick it, not your bank."),
                        i18nc("Selecione a conta is a label on the Meu Pluggy authorization page; keep it as is",
                              "Sign in with your Meu Pluggy account and, under <b>“Selecione a conta”</b>, pick <b>one</b> bank and authorize."),
                        i18n("Each authorization shares one bank. <b>Repeat these steps for every bank</b> you want in Saldo (up to 5). Authorizations last one year.")
                    ]
                }
                UI.Banner {
                    Layout.fillWidth: true
                    type: Kirigami.MessageType.Information
                    visible: true
                    text: i18nc("Customização, Conectores, Conectores Diretos and Pessoal are labels in the Pluggy dashboard; keep them as is",
                                "MeuPluggy not in the list? In the dashboard, enable it under “Customização” → “Conectores” (tab “Conectores Diretos”, group “Pessoal”).")
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    UI.Button {
                        text: i18n("Open the Pluggy Dashboard")
                        icon.name: "internet-services-symbolic"
                        onClicked: Qt.openUrlExternally(page.dashboardUrl)
                    }
                    UI.Button {
                        text: i18n("All My Banks Are Connected")
                        icon.name: "go-next-symbolic"
                        onClicked: page.advance(3)
                    }
                }
            }

            // 4 ─ Item IDs
            SetupStep {
                Layout.fillWidth: true
                number: 4
                title: i18n("Paste the item ID")
                summary: i18np("%1 connection added.", "%1 connections added.", Config.itemIds.length)
                status: page.statusOf(4, page.step4Done)
                expanded: page.openStep === 4
                onHeaderClicked: page.selectedStep = 4

                QQC2.Label {
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    text: i18nc("Itens Conectados is a label in the Pluggy dashboard; keep it as is",
                                "On the demo page, under <b>“Itens Conectados”</b>, there is one item per bank you authorized. Copy the <b>id</b> of each one and paste it here; several at once works. It is not the Client ID.")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    enabled: Config.itemIds.length < 5
                    UI.TextField {
                        id: itemField
                        Layout.fillWidth: true
                        placeholderText: i18n("Item ID")
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        font.family: Kirigami.Theme.fixedWidthFont?.family ?? UI.Tokens.monospaceFamily
                        onAccepted: page.addItems(text)
                    }
                    UI.Button {
                        icon.name: "edit-paste"
                        text: i18n("Paste")
                        display: QQC2.AbstractButton.IconOnly
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        onClicked: {
                            itemField.clear();
                            itemField.paste();
                            page.addItems(itemField.text);
                        }
                    }
                    UI.Button {
                        text: i18n("Add")
                        icon.name: "list-add"
                        enabled: itemField.text.trim().length > 0
                        onClicked: page.addItems(itemField.text)
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: page.itemMessage.length > 0
                    text: page.itemMessage
                    wrapMode: Text.Wrap
                    color: page.itemOk ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }

                Repeater {
                    model: ItemsModel {}
                    delegate: RowLayout {
                        id: itemRow
                        required property var model
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignTop
                            source: itemRow.model.status.length === 0 ? "data-information" : itemRow.model.healthy ? "emblem-ok-symbolic" : "data-warning"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: itemRow.model.connectorName
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: itemRow.model.accountsSummary.length > 0 ? itemRow.model.accountsSummary : itemRow.model.itemId
                                elide: Text.ElideMiddle
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }
                        }
                        UI.IconButton {
                            icon.name: "document-edit"
                            text: i18n("Name this connection")
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: renameDialog.openFor(itemRow.model.itemId, itemRow.model.nickname, itemRow.model.accountsSummary)
                        }
                        UI.IconButton {
                            icon.name: "list-remove"
                            text: i18n("Remove connection")
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: Config.removeItemId(itemRow.model.itemId)
                        }
                    }
                }

                UI.Button {
                    text: i18n("Continue")
                    icon.name: "go-next-symbolic"
                    enabled: Config.itemIds.length > 0
                    onClicked: {
                        page.advance(4);
                        SyncManager.sync();
                    }
                }
            }

            // 5 ─ First sync
            SetupStep {
                Layout.fillWidth: true
                number: 5
                last: true
                title: i18n("Download your data")
                summary: page.step5Done ? i18n("Your accounts are in Saldo.") : ""
                status: page.statusOf(5, page.step5Done)
                expanded: page.openStep === 5
                onHeaderClicked: page.selectedStep = 5

                RowLayout {
                    Layout.fillWidth: true
                    visible: SyncManager.running
                    spacing: Kirigami.Units.largeSpacing
                    UI.BusyIndicator {
                        running: SyncManager.running
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: SyncManager.progressText.length > 0 ? SyncManager.progressText : i18n("Syncing with Pluggy…")
                        wrapMode: Text.Wrap
                    }
                }

                UI.Banner {
                    Layout.fillWidth: true
                    type: Kirigami.MessageType.Error
                    visible: !SyncManager.running && SyncManager.lastError.length > 0
                    text: SyncManager.lastError
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: !SyncManager.running && !page.step5Done
                    text: i18n("If nothing shows up right after connecting, Pluggy may still be importing your banks. Wait a few minutes and try again.")
                    wrapMode: Text.Wrap
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: page.step5Done && Config.itemIds.length > 1
                    text: i18n("Tip: give each connection a name (Nubank, Inter…) in step 4 so accounts and cards are grouped by bank.")
                    wrapMode: Text.Wrap
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: page.step5Done
                    text: i18n("All set: %1, %2 and %3. Pluggy refreshes your banks once a day and Saldo picks it up on its own.",
                               i18np("%1 account", "%1 accounts", FinanceSummary.accountCount),
                               i18np("%1 card", "%1 cards", FinanceSummary.cardCount),
                               i18np("%1 investment", "%1 investments", FinanceSummary.investmentCount))
                    wrapMode: Text.Wrap
                    color: Kirigami.Theme.positiveTextColor
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    UI.Button {
                        visible: page.step5Done
                        text: i18n("See My Finances")
                        icon.name: "view-statistics"
                        onClicked: applicationWindow().showPage("overview")
                    }
                    UI.Button {
                        text: page.step5Done ? i18n("Sync Again") : i18n("Sync Now")
                        icon.name: "view-refresh"
                        enabled: !SyncManager.running && Credentials.configured && Config.itemIds.length > 0
                        onClicked: SyncManager.sync()
                    }
                }
            }
        }
    }
}
