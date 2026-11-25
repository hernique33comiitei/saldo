// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI

// The design system's catalog (`saldo --demo --page gallery`, on the phone
// `tools/phone-test.sh run --demo --page gallery`): every org.saldo.ui
// component in its states, to review them in light and dark on both
// platforms. A development page, reached only by --page; its texts are
// samples, not translated.
Kirigami.ScrollablePage {
    id: page

    Component.onCompleted: {
        if (UI.Platform.isPhone) {
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

    title: "Design system"

    // A titled block of the catalog.
    component Section: ColumnLayout {
        property alias title: sectionTitle.text
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        QQC2.Label {
            id: sectionTitle
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit
            font.family: "monospace"
            wrapMode: Text.Wrap
            opacity: 0.6
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        Section {
            title: "Interactive (first, for adb taps): UI.Sheet · UI.ConfirmSheet · UI.Select"
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                UI.Button {
                    text: "Open sheet"
                    onClicked: sampleSheet.open()
                }
                UI.Button {
                    text: "Open confirmation"
                    onClicked: sampleConfirm.open()
                }
            }
            UI.Select {
                Layout.fillWidth: true
                model: ["System default", "English", "Português (Brasil)"]
            }
        }

        Section {
            title: "UI.Card: title + action · title · tile (no title)"
            UI.Card {
                Layout.fillWidth: true
                title: "Credit limit"
                headerActions: [
                    Kirigami.Action {
                        text: "Cards"
                        icon.name: "go-next-symbolic"
                    }
                ]
                QQC2.Label {
                    text: "Content goes into a column."
                }
            }
            UI.Card {
                Layout.fillWidth: true
                title: "Spending by category"
                QQC2.Label {
                    text: "A card with a title only."
                }
            }
            UI.Card {
                Layout.fillWidth: true
                UI.IconBadge {
                    source: "view-financial-account-investment"
                }
                QQC2.Label {
                    text: "A tile: no title, no header."
                }
            }
        }

        Section {
            title: "UI.IconBadge: highlight · positive · neutral · negative · disabled"
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: [Kirigami.Theme.highlightColor, Kirigami.Theme.positiveTextColor, Kirigami.Theme.neutralTextColor,
                            Kirigami.Theme.negativeTextColor, Kirigami.Theme.disabledTextColor]
                    delegate: UI.IconBadge {
                        required property color modelData
                        source: "view-financial-account-credit-card"
                        tint: modelData
                    }
                }
            }
        }

        Section {
            title: "UI.Chip: checked · unchecked · drop-down · disabled"
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                UI.Chip {
                    text: "All"
                    checked: true
                }
                UI.Chip {
                    text: "Income"
                }
                UI.Chip {
                    text: "All months"
                    dropDown: true
                }
                UI.Chip {
                    text: "Disabled"
                    enabled: false
                }
            }
        }

        Section {
            title: "UI.DrawerItem: active · idle"
            UI.DrawerItem {
                text: "Settings"
                iconName: "configure"
                active: true
            }
            UI.DrawerItem {
                text: "About Saldo"
                iconName: "help-about"
            }
        }

        Section {
            title: "UI.SummaryHeader"
            UI.SummaryHeader {
                Layout.fillWidth: true
                QQC2.Label {
                    text: "Total in accounts · R$ 23.650,65"
                }
            }
        }

        Section {
            title: "UI.SectionHeader"
            UI.SectionHeader {
                Layout.fillWidth: true
                section: "Friday, November 20, 2026"
            }
        }

        Section {
            title: "UI.TabBar"
            UI.TabBar {
                Layout.fillWidth: true
                actions: [
                    Kirigami.Action {
                        text: "Overview"
                        icon.name: "view-statistics"
                        checked: true
                    },
                    Kirigami.Action {
                        text: "Accounts"
                        icon.name: "view-bank"
                    },
                    Kirigami.Action {
                        text: "Cards"
                        icon.name: "view-financial-account-credit-card"
                    }
                ]
            }
        }

        Section {
            title: "UI.Button: primary · secondary · flat · icon · disabled"
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                UI.Button {
                    text: "Save"
                    variant: UI.Button.Primary
                }
                UI.Button {
                    text: "Test Connection"
                }
                UI.Button {
                    text: "Cancel"
                    variant: UI.Button.Flat
                }
                UI.Button {
                    text: "Sync Now"
                    icon.name: "view-refresh"
                }
                UI.Button {
                    text: "Disabled"
                    variant: UI.Button.Primary
                    enabled: false
                }
            }
        }

        Section {
            title: "UI.IconButton"
            Row {
                spacing: Kirigami.Units.smallSpacing
                UI.IconButton {
                    icon.name: "document-edit"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Rename"
                }
                UI.IconButton {
                    icon.name: "edit-delete"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Remove"
                }
            }
        }

        Section {
            title: "UI.TextField: empty · filled · error · disabled"
            UI.TextField {
                Layout.fillWidth: true
                placeholderText: "Client ID"
            }
            UI.TextField {
                Layout.fillWidth: true
                text: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
            }
            UI.TextField {
                Layout.fillWidth: true
                text: "not an id"
                error: true
            }
            UI.TextField {
                Layout.fillWidth: true
                placeholderText: "Disabled"
                enabled: false
            }
        }

        Section {
            title: "UI.PasswordField · UI.SearchField · UI.TextArea"
            UI.PasswordField {
                Layout.fillWidth: true
                placeholderText: "Client Secret"
            }
            UI.SearchField {
                Layout.fillWidth: true
            }
            UI.TextArea {
                Layout.fillWidth: true
                text: "{\n  \"id\": \"3fa85f64\"\n}"
            }
        }

        Section {
            title: "UI.NumberField"
            UI.NumberField {
                from: 1
                to: 24
                value: 12
            }
        }

        Section {
            title: "UI.Switch: off · on · with text · disabled"
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                UI.Switch {}
                UI.Switch {
                    checked: true
                }
                UI.Switch {
                    text: "Count this card"
                    checked: true
                }
                UI.Switch {
                    enabled: false
                }
            }
        }

        Section {
            title: "UI.Banner: information · positive · warning · error"
            Repeater {
                model: [
                    { type: Kirigami.MessageType.Information, text: "Pluggy updates your banks once a day." },
                    { type: Kirigami.MessageType.Positive, text: "Connected and saved in the system keyring." },
                    { type: Kirigami.MessageType.Warning, text: "The authorization of Banco Exemplo ends in 12 days." },
                    { type: Kirigami.MessageType.Error, text: "Pluggy refused the credentials." }
                ]
                delegate: UI.Banner {
                    required property var modelData
                    Layout.fillWidth: true
                    visible: true
                    type: modelData.type
                    text: modelData.text
                }
            }
        }

        Section {
            title: "UI.EmptyState · UI.BusyIndicator"
            UI.EmptyState {
                Layout.fillWidth: true
                icon.name: "view-financial-list"
                text: "No transactions"
                explanation: "Transactions appear here after a sync."
            }
            UI.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: true
            }
        }

        Item {
            implicitHeight: Kirigami.Units.gridUnit
        }
    }

    UI.Sheet {
        id: sampleSheet
        title: "Rename connection"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.gridUnit
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                text: "Name"
            }
            UI.TextField {
                Layout.fillWidth: true
                text: "Banco Exemplo"
            }
        }
    }

    UI.ConfirmSheet {
        id: sampleConfirm
        title: "Remove the connection?"
        subtitle: "Its accounts and transactions leave Saldo; you can add it again later."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    }
}
