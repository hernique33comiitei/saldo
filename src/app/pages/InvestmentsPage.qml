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

    title: i18n("Investments")

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
            iconName: "view-financial-account-investment"
            label: i18n("Total invested (net)")
            value: investments.total
            emphasized: true
        }
    }

    ListView {
        id: list

        model: InvestmentsModel {
            id: investments
        }

        section.property: "typeLabel"
        section.delegate: UI.SectionHeader {}

        delegate: UI.ListRow {
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
            hoverEnabled: false
            down: false
            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    visible: !page.phone
                    source: "view-financial-account-investment"
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }
                UI.IconBadge {
                    visible: page.phone
                    source: "view-financial-account-investment"
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
                        font.weight: page.phone ? Font.DemiBold : Font.Normal
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

        UI.EmptyState {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: list.count === 0
            icon.name: "view-financial-account-investment"
            text: i18n("No investments")
            explanation: i18n("Investments appear here when your institutions share them through Meu Pluggy.")
        }
    }
}
