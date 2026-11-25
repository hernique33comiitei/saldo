// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts
import org.saldo.core

// The overview on phones (Main.qml picks it there; OverviewPage is the
// desktop's): a headline card, the months as chips, tiles and one column of
// cards. Same data and month rules as OverviewPage.
RefreshablePage {
    id: page

    // The month the user picked ("yyyy-MM"); kept across syncs, which rebuild
    // the list. Empty = the newest month.
    property string chosenMonth
    // Everything on this page that depends on a month follows it.
    readonly property string month: {
        const months = FinanceSummary.months;
        if (chosenMonth.length > 0 && months.some(entry => entry.value === chosenMonth)) {
            return chosenMonth;
        }
        return months.length > 0 ? months[0].value : "";
    }

    title: i18n("Overview")

    actions: [
        Kirigami.Action {
            text: Config.privacyMode ? i18n("Show Values") : i18n("Hide Values")
            icon.name: Config.privacyMode ? "view-visible" : "view-hidden"
            displayHint: Kirigami.DisplayHint.IconOnly
            onTriggered: Config.privacyMode = !Config.privacyMode
        },
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            displayHint: Kirigami.DisplayHint.IconOnly
            enabled: Credentials.configured && !SyncManager.running
            onTriggered: SyncManager.sync()
        }
    ]

    header: SyncBanner {}

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        CashflowModel {
            id: cashflow
            months: 6
            endMonth: page.month
        }

        NoDataMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit * 4
        }

        BalanceHero {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData
            balance: FinanceSummary.totalCash
            caption: i18np("%1 account", "%1 accounts", FinanceSummary.accountCount)
            income: cashflow.endIncome
            expense: cashflow.endExpense
        }

        // The months as chips, scrolling sideways past the page's margins.
        ListView {
            id: monthChips
            Layout.fillWidth: true
            Layout.leftMargin: -page.leftPadding
            Layout.rightMargin: -page.rightPadding
            implicitHeight: contentItem.childrenRect.height
            visible: FinanceSummary.hasData && count > 0
            orientation: ListView.Horizontal
            spacing: Kirigami.Units.smallSpacing
            leftMargin: page.leftPadding
            rightMargin: page.rightPadding
            clip: true
            model: FinanceSummary.months
            delegate: FilterChip {
                required property var modelData
                text: modelData.text
                checked: modelData.value === page.month
                onClicked: page.chosenMonth = modelData.value
            }
        }

        // Two headline tiles side by side.
        GridLayout {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            Repeater {
                model: [
                    {
                        title: i18n("Invested"),
                        icon: "view-financial-account-investment",
                        value: FinanceSummary.totalInvested,
                        caption: i18np("%1 investment", "%1 investments", FinanceSummary.investmentCount),
                        tint: Kirigami.Theme.highlightColor
                    },
                    {
                        title: i18n("Next bills"),
                        icon: "view-financial-account-credit-card",
                        value: FinanceSummary.nextBills,
                        caption: FinanceSummary.nextBillDue.getTime && !isNaN(FinanceSummary.nextBillDue.getTime())
                                 ? i18n("due %1", Money.shortDate(FinanceSummary.nextBillDue))
                                 : i18np("%1 card", "%1 cards", FinanceSummary.cardCount),
                        tint: Kirigami.Theme.neutralTextColor
                    }
                ]
                delegate: Surface {
                    id: tile
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    padding: Kirigami.Units.largeSpacing * 1.5

                    IconBadge {
                        source: tile.modelData.icon
                        tint: tile.modelData.tint
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: tile.modelData.title
                            elide: Text.ElideRight
                            opacity: 0.8
                        }
                        MoneyLabel {
                            Layout.fillWidth: true
                            value: tile.modelData.value
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                            font.weight: Font.Bold
                            fontSizeMode: Text.HorizontalFit
                            minimumPointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: tile.modelData.caption
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }
            }
        }

        // Credit limit as a bar: used and available above it, the share and
        // the total below.
        Surface {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData && FinanceSummary.cardCount > 0
            title: i18n("Credit limit")
            actionText: i18n("Cards")
            onActionTriggered: applicationWindow().showPage("cards")

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: [
                        { name: i18n("Used"), value: FinanceSummary.cardUsed, alignment: Qt.AlignLeft },
                        { name: i18n("Available"), value: FinanceSummary.cardAvailable, alignment: Qt.AlignRight }
                    ]
                    delegate: ColumnLayout {
                        id: limitPart
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: limitPart.modelData.alignment === Qt.AlignRight ? Text.AlignRight : Text.AlignLeft
                            text: limitPart.modelData.name
                            elide: Text.ElideRight
                            opacity: 0.8
                        }
                        MoneyLabel {
                            Layout.fillWidth: true
                            horizontalAlignment: limitPart.modelData.alignment === Qt.AlignRight ? Text.AlignRight : Text.AlignLeft
                            value: limitPart.modelData.value
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                            font.weight: Font.Bold
                            fontSizeMode: Text.HorizontalFit
                            minimumPointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                        }
                    }
                }
            }
            LimitBar {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.smallSpacing * 2.5
                ratio: FinanceSummary.cardUsedRatio
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("%1% used", Math.round(FinanceSummary.cardUsedRatio * 100))
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                }
                QQC2.Label {
                    text: i18n("Total limit")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                }
                MoneyLabel {
                    value: FinanceSummary.cardLimit
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                }
            }
        }

        // Spending: one row per category, its share as a bar.
        Surface {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData
            title: i18n("Spending by category")

            Charts.ColorGradientSource {
                id: categoryColors
                baseColor: Kirigami.Theme.highlightColor
                itemCount: Math.max(1, spending.count)
            }

            Repeater {
                model: CategorySpendModel {
                    id: spending
                    month: page.month
                }
                delegate: RowLayout {
                    id: category
                    required property int index
                    required property string name
                    required property real amount
                    required property real ratio
                    required property string iconName
                    readonly property color tint: categoryColors.colors[index] ?? Kirigami.Theme.highlightColor

                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    IconBadge {
                        source: category.iconName
                        tint: category.tint
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: category.name
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                text: Money.percent(category.ratio)
                                font.features: { "tnum": 1 }
                                opacity: 0.7
                            }
                            MoneyLabel {
                                value: category.amount
                            }
                        }
                        // The category's share of the month's spending.
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: Kirigami.Units.smallSpacing * 1.5
                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)
                            }
                            Rectangle {
                                width: Math.max(height, parent.width * category.ratio)
                                height: parent.height
                                radius: height / 2
                                color: category.tint
                            }
                        }
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: spending.count === 0
                text: i18n("No expenses in this month.")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                opacity: 0.7
            }
        }

        Surface {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData
            title: i18n("Income and expenses")
            CashflowChart {
                Layout.fillWidth: true
                showLegend: false
                model: cashflow
            }
        }

        Surface {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData && FinanceSummary.accountCount > 0
            title: i18n("Balance in accounts, last 90 days")
            BalanceChart {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 9
                model: BalanceHistoryModel {
                    id: balance
                    days: 90
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                // Snapshots exist only since Saldo started recording.
                visible: balance.count >= 2 && (Date.now() - balance.firstDay.getTime()) / 86400000 < balance.days - 1
                text: i18n("Saldo records the balance once a day; the history starts on %1.", Money.shortDate(balance.firstDay))
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        SyncStatusLabel {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.largeSpacing
        }
    }
}
