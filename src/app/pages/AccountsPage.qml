// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI
import org.saldo.core

RefreshablePage {
    id: page

    // Phones: round icons and bold names in the rows.
    readonly property bool phone: Kirigami.Settings.isMobile

    title: i18n("Accounts")

    actions: [
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            // No shortcuts on phones: a menu showed them over the text ("Ctrl+H").
            shortcut: Kirigami.Settings.isMobile ? "" : StandardKey.Refresh
            displayHint: page.phone ? Kirigami.DisplayHint.IconOnly : Kirigami.DisplayHint.NoPreference
            enabled: Credentials.configured && !SyncManager.running
            onTriggered: SyncManager.sync()
        }
    ]

    header: UI.SummaryHeader {
        visible: list.count > 0
        SummaryRow {
            Layout.fillWidth: true
            iconName: "view-bank"
            label: i18n("Total in accounts")
            value: accounts.total
            warnNegative: true
            emphasized: true
        }
    }

    Component {
        id: desktopSection
        Kirigami.ListSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
        }
    }
    Component {
        id: phoneSection
        UI.SectionHeader {}
    }

    ListView {
        id: list

        model: AccountsModel {
            id: accounts
            type: "BANK"
        }

        section.property: "institution"
        section.delegate: page.phone ? phoneSection : desktopSection

        delegate: QQC2.ItemDelegate {
            id: delegate
            required property var model

            width: ListView.view.width
            // Phones: the page's side margins, more room between rows. Set
            // here, not bound, so the desktop keeps the style's own paddings.
            Component.onCompleted: {
                if (page.phone) {
                    leftPadding = Kirigami.Units.gridUnit;
                    rightPadding = Kirigami.Units.gridUnit;
                    topPadding = Kirigami.Units.largeSpacing;
                    bottomPadding = Kirigami.Units.largeSpacing;
                }
            }
            onClicked: applicationWindow().pageStack.push(transactionsComponent, {
                accountId: model.accountId,
                title: model.name
            })

            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    visible: !page.phone
                    source: delegate.model.iconName
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }
                UI.IconBadge {
                    visible: page.phone
                    source: delegate.model.iconName
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: delegate.model.name
                        font.weight: page.phone ? Font.DemiBold : Font.Normal
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
                    font.weight: page.phone ? Font.DemiBold : Font.Normal
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
