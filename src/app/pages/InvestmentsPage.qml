// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

RefreshablePage {
    id: page

    title: i18n("Investments")

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
            iconName: "view-financial-account-investment"
            label: i18n("Total invested (net)")
            value: investments.total
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

        model: InvestmentsModel {
            id: investments
        }

        section.property: "typeLabel"
        section.delegate: Kirigami.ListSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
        }

        delegate: QQC2.ItemDelegate {
            id: delegate
            required property var model

            width: ListView.view.width
            hoverEnabled: false
            down: false
            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    source: "view-financial-account-investment"
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
                        text: [
                            delegate.model.institution,
                            delegate.model.dueLabel ? i18n("matures %1", delegate.model.dueLabel) : "",
                            delegate.model.lastTwelveMonthsRate !== 0 ? i18n("%1% in 12 months", Money.number(delegate.model.lastTwelveMonthsRate, 1)) : ""
                        ].filter(part => part && part.length > 0).join(" · ")
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
                ColumnLayout {
                    spacing: 0
                    MoneyLabel {
                        Layout.alignment: Qt.AlignRight
                        value: delegate.model.balance
                        currency: delegate.model.currency
                    }
                    MoneyLabel {
                        Layout.alignment: Qt.AlignRight
                        visible: delegate.model.profit !== 0
                        value: delegate.model.profit
                        currency: delegate.model.currency
                        signed: true
                        colored: true
                        warnNegative: true
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: list.count === 0
            icon.name: "view-financial-account-investment"
            text: i18n("No investments")
            explanation: i18n("Investments appear here when your institutions share them through Meu Pluggy.")
        }
    }
}
