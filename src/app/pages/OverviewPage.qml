// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

Kirigami.ScrollablePage {
    id: page

    readonly property bool wide: width > Kirigami.Units.gridUnit * 40
    // "yyyy-MM" picked at the top; empty = current month. Everything on this
    // page that depends on a month follows it.
    readonly property string month: monthBox.currentValue ?? ""

    title: i18n("Overview")

    actions: [
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            shortcut: StandardKey.Refresh
            enabled: Credentials.configured && !SyncManager.running
            onTriggered: SyncManager.sync()
        },
        Kirigami.Action {
            text: Config.privacyMode ? i18n("Show Values") : i18n("Hide Values")
            icon.name: Config.privacyMode ? "view-visible" : "view-hidden"
            shortcut: "Ctrl+H"
            onTriggered: Config.privacyMode = !Config.privacyMode
        }
    ]

    header: SyncBanner {}

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit * 4
            visible: !FinanceSummary.hasData
            icon.name: Credentials.configured ? "view-refresh" : "wallet-open"
            text: {
                if (!Credentials.configured) {
                    return i18n("Connect your Meu Pluggy account");
                }
                return SyncManager.running ? i18n("Downloading your data…") : i18n("No data yet");
            }
            explanation: Credentials.configured
                ? i18n("Your accounts appear here as soon as the first sync finishes.")
                : i18n("Saldo reads your banks through the free Meu Pluggy personal-use API. You need a Client ID, a Client Secret and the item ID of each connection.")
            helpfulAction: Kirigami.Action {
                enabled: !SyncManager.running
                text: Credentials.configured ? i18n("Sync Now") : i18n("Set Up Meu Pluggy")
                icon.name: Credentials.configured ? "view-refresh" : "configure"
                onTriggered: Credentials.configured ? SyncManager.sync() : applicationWindow().showPage("setup")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData && monthBox.count > 0
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Month:")
            }
            QQC2.ComboBox {
                id: monthBox

                // The list is rebuilt after every sync; keep the month the
                // user picked instead of jumping back to the latest one.
                property string chosen

                model: FinanceSummary.months
                textRole: "text"
                valueRole: "value"
                onActivated: chosen = currentValue
                onModelChanged: Qt.callLater(() => {
                    if (chosen.length > 0) {
                        currentIndex = Math.max(0, indexOfValue(chosen));
                    }
                })
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData
            columns: page.width > Kirigami.Units.gridUnit * 30 ? 3 : 1
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Kirigami.Units.gridUnit

            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                title: i18n("In accounts")
                iconName: "view-bank"
                value: FinanceSummary.totalCash
                warnNegative: true
                caption: i18np("%1 account", "%1 accounts", FinanceSummary.accountCount)
            }
            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                title: i18n("Invested")
                iconName: "view-financial-account-investment"
                value: FinanceSummary.totalInvested
                caption: i18np("%1 investment", "%1 investments", FinanceSummary.investmentCount)
            }
            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                title: i18n("Next bills")
                iconName: "view-financial-account-credit-card"
                value: FinanceSummary.nextBills
                caption: FinanceSummary.nextBillDue.getTime && !isNaN(FinanceSummary.nextBillDue.getTime())
                         ? i18n("due %1", Money.shortDate(FinanceSummary.nextBillDue))
                         : i18np("%1 card", "%1 cards", FinanceSummary.cardCount)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData
            // Side by side only while the spending chart keeps its legend beside
            // the ring; stacked, it grows taller and the limit card beside it
            // would stretch into empty space.
            columns: page.wide && (width - columnSpacing) / 2 - Kirigami.Units.gridUnit * 2 >= spendingDonut.minimumHorizontalWidth ? 2 : 1
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Kirigami.Units.gridUnit

            SectionCard {
                id: limitCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                title: i18n("Credit limit")
                visible: FinanceSummary.cardCount > 0
                headerActions: [
                    Kirigami.Action {
                        text: i18n("Cards")
                        icon.name: "go-next-symbolic"
                        onTriggered: applicationWindow().showPage("cards")
                    }
                ]

                // Ring beside the numbers when both fit the card, above them on
                // narrow windows. Decided from the card's width (set by the page,
                // not by this content), so it cannot feed back into itself.
                GridLayout {
                    id: limitRow
                    readonly property bool sideBySide: limitCard.width - limitCard.leftPadding - limitCard.rightPadding
                                                       >= limitDonut.implicitWidth + columnSpacing + limitNumbers.implicitWidth
                    Layout.fillWidth: true
                    columns: sideBySide ? 3 : 1
                    columnSpacing: Kirigami.Units.largeSpacing * 2
                    rowSpacing: 0

                    // Stacked: each item spans the column but keeps its own size,
                    // so it is centered in the card (like the spending ring); the
                    // filler below stretches the column to the card's width.
                    LimitDonut {
                        id: limitDonut
                        Layout.fillWidth: !limitRow.sideBySide
                        Layout.maximumWidth: implicitWidth
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: limitRow.sideBySide ? 0 : Kirigami.Units.largeSpacing
                        used: FinanceSummary.cardUsed
                        limit: FinanceSummary.cardLimit
                    }
                    // Sized to its content: amounts right-aligned in their own
                    // column, one grid unit from the longest label.
                    GridLayout {
                        id: limitNumbers
                        Layout.fillWidth: !limitRow.sideBySide
                        Layout.maximumWidth: implicitWidth
                        Layout.alignment: limitRow.sideBySide ? Qt.AlignVCenter : Qt.AlignHCenter
                        columns: 2
                        columnSpacing: Kirigami.Units.gridUnit
                        rowSpacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: i18n("Total limit")
                            font.weight: Font.DemiBold
                        }
                        MoneyLabel {
                            Layout.alignment: Qt.AlignRight
                            value: FinanceSummary.cardLimit
                            font.weight: Font.DemiBold
                        }
                        QQC2.Label {
                            text: i18n("Used")
                        }
                        MoneyLabel {
                            Layout.alignment: Qt.AlignRight
                            value: FinanceSummary.cardUsed
                        }
                        QQC2.Label {
                            text: i18n("Available")
                        }
                        MoneyLabel {
                            Layout.alignment: Qt.AlignRight
                            value: FinanceSummary.cardAvailable
                        }
                    }

                    // Side by side: the space right of the numbers. Stacked: a
                    // zero-height last row that makes the column full width.
                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            SectionCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                title: i18n("Spending by category")

                CategoryDonut {
                    id: spendingDonut
                    Layout.fillWidth: true
                    visible: spending.count > 0
                    model: CategorySpendModel {
                        id: spending
                        month: page.month
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: spending.count === 0
                    text: i18n("No expenses in this month.")
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.7
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: FinanceSummary.hasData
            columns: page.wide ? 2 : 1
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Kirigami.Units.gridUnit

            SectionCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                title: i18n("Income and expenses")

                // Totals of the picked month (its pair of bars is the last one),
                // doubling as the chart's legend. A Flow, so the second one
                // drops below the first on narrow windows instead of pushing the
                // card (and the chart) wider than the window.
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: [
                            { name: i18n("Income in the month"), value: cashflow.endIncome, color: Kirigami.Theme.positiveTextColor },
                            { name: i18n("Expenses in the month"), value: cashflow.endExpense, color: Kirigami.Theme.negativeTextColor }
                        ]
                        delegate: Item {
                            id: total
                            required property var modelData
                            required property int index
                            // The gap goes after the first total only: room after
                            // the last one made the pair wrap on phones although
                            // both fit.
                            implicitWidth: totalColumn.implicitWidth + (index === 0 ? Kirigami.Units.gridUnit * 2 : 0)
                            implicitHeight: totalColumn.implicitHeight

                            ColumnLayout {
                                id: totalColumn
                                spacing: 0
                                RowLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Rectangle {
                                        implicitWidth: Kirigami.Units.smallSpacing * 2
                                        implicitHeight: implicitWidth
                                        radius: width / 2
                                        color: total.modelData.color
                                    }
                                    QQC2.Label {
                                        text: total.modelData.name
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.8
                                    }
                                }
                                MoneyLabel {
                                    value: total.modelData.value
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                CashflowChart {
                    Layout.fillWidth: true
                    showLegend: false
                    model: CashflowModel {
                        id: cashflow
                        months: 6
                        endMonth: page.month
                    }
                }
            }

            SectionCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                title: i18n("Balance in accounts, last 90 days")
                visible: FinanceSummary.accountCount > 0
                BalanceChart {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 10
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
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            visible: FinanceSummary.hasData
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: {
                const parts = [];
                if (FinanceSummary.dataUpdatedAt.getTime && !isNaN(FinanceSummary.dataUpdatedAt.getTime())) {
                    parts.push(i18n("Pluggy updated your banks %1", Money.relativeTime(FinanceSummary.dataUpdatedAt)));
                }
                if (FinanceSummary.nextAutoSyncAt.getTime && !isNaN(FinanceSummary.nextAutoSyncAt.getTime())) {
                    // Pluggy's schedule can be in the past while its daily update
                    // is still running or late: "next update 28 minutes ago" read
                    // as if it were coming.
                    parts.push(FinanceSummary.nextAutoSyncAt.getTime() > Date.now()
                               ? i18n("next update %1", Money.relativeTime(FinanceSummary.nextAutoSyncAt))
                               : i18n("next update soon"));
                }
                parts.push(i18n("last checked %1", Money.relativeTime(SyncManager.lastSyncAt)));
                return parts.join(" · ");
            }
        }
    }
}
