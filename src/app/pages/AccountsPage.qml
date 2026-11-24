// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

RefreshablePage {
    id: page

    title: i18n("Accounts")

    actions: [
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            // No shortcuts on phones: a menu showed them over the text ("Ctrl+H").
            shortcut: Kirigami.Settings.isMobile ? "" : StandardKey.Refresh
            enabled: Credentials.configured && !SyncManager.running
            onTriggered: SyncManager.sync()
        }
    ]

    header: QQC2.Control {
        visible: list.count > 0
        padding: Kirigami.Units.largeSpacing
        contentItem: SummaryRow {
            iconName: "view-bank"
            label: i18n("Total in accounts")
            value: accounts.total
            warnNegative: true
            emphasized: true
        }
        background: Rectangle {
            color: Kirigami.Theme.alternateBackgroundColor
            Kirigami.Separator {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
            }
        }
    }

    ListView {
        id: list

        model: AccountsModel {
            id: accounts
            type: "BANK"
        }

        section.property: "institution"
        section.delegate: Kirigami.ListSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
        }

        delegate: QQC2.ItemDelegate {
            id: delegate
            required property var model

            width: ListView.view.width
            onClicked: applicationWindow().pageStack.push(transactionsComponent, {
                accountId: model.accountId,
                title: model.name
            })

            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    source: delegate.model.iconName
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: delegate.model.name
                        elide: Text.ElideRight
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: [delegate.model.subtypeLabel, delegate.model.numberLabel].filter(part => part && part.length > 0).join(" · ")
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
                MoneyLabel {
                    value: delegate.model.balance
                    currency: delegate.model.currency
                    warnNegative: true
                }
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: list.count === 0
            icon.name: "view-bank"
            text: i18n("No bank accounts")
            explanation: Credentials.configured
                ? i18n("Accounts from your Meu Pluggy connections show up here after a sync.")
                : i18n("Set up Meu Pluggy to see your accounts.")
            helpfulAction: Kirigami.Action {
                text: Credentials.configured ? i18n("Sync Now") : i18n("Set Up Meu Pluggy")
                icon.name: Credentials.configured ? "view-refresh" : "configure"
                enabled: !SyncManager.running
                onTriggered: Credentials.configured ? SyncManager.sync() : applicationWindow().showPage("setup")
            }
        }
    }

    Component {
        id: transactionsComponent
        TransactionsPage {}
    }
}
