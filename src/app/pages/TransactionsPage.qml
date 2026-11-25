// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI
import org.saldo.core

RefreshablePage {
    id: page

    // Optional: only this account's transactions.
    property string accountId: ""
    // Phones: filters as chips, totals as tiles, rows with round icons.
    readonly property bool phone: Kirigami.Settings.isMobile

    title: i18n("Transactions")

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

    header: QQC2.Control {
        padding: Kirigami.Units.largeSpacing
        // Phones: the page's side margins. Set here, not bound, so the
        // desktop keeps the style's own paddings.
        Component.onCompleted: {
            if (page.phone) {
                leftPadding = Kirigami.Units.gridUnit;
                rightPadding = Kirigami.Units.gridUnit;
            }
        }
        contentItem: ColumnLayout {
            spacing: page.phone ? Kirigami.Units.largeSpacing : Kirigami.Units.smallSpacing

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                UI.SearchField {
                    id: search
                    width: page.phone ? parent.width : Math.min(Kirigami.Units.gridUnit * 16, parent.width)
                    delaySearch: true
                    onAccepted: transactions.searchText = text
                }
                UI.Select {
                    id: monthBox
                    visible: !page.phone
                    model: [{ text: i18n("All months"), value: "" }].concat(FinanceSummary.months)
                    textRole: "text"
                    valueRole: "value"
                    onActivated: transactions.month = currentValue
                    // The list is rebuilt (newest first) whenever the summary
                    // reloads; stay on the month the list is filtered by.
                    onModelChanged: Qt.callLater(() => currentIndex = Math.max(0, indexOfValue(transactions.month)))
                }
                UI.Select {
                    id: kindBox
                    visible: !page.phone
                    model: [
                        { text: i18n("Income and expenses"), value: TransactionsModel.All },
                        { text: i18n("Income only"), value: TransactionsModel.Income },
                        { text: i18n("Expenses only"), value: TransactionsModel.Expense }
                    ]
                    textRole: "text"
                    valueRole: "value"
                    onActivated: transactions.kind = currentValue
                }
            }

            // Phones: the month (a menu) and the kind as chips, scrolling
            // sideways when they do not fit.
            Flickable {
                Layout.fillWidth: true
                visible: page.phone
                implicitHeight: chips.implicitHeight
                contentWidth: chips.implicitWidth
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: chips
                    spacing: Kirigami.Units.smallSpacing

                    UI.Chip {
                        id: monthChip
                        dropDown: true
                        checked: transactions.month.length > 0
                        text: {
                            const month = transactions.month;
                            const entry = FinanceSummary.months.find(candidate => candidate.value === month);
                            return month.length > 0 && entry ? entry.text : i18n("All months");
                        }
                        onClicked: monthMenu.popup(monthChip, 0, monthChip.height)
                    }
                    Repeater {
                        model: [
                            { text: i18nc("@option:check transaction filter chip: income and expenses", "All"), value: TransactionsModel.All },
                            { text: i18n("Income"), value: TransactionsModel.Income },
                            { text: i18n("Expenses"), value: TransactionsModel.Expense }
                        ]
                        delegate: UI.Chip {
                            required property var modelData
                            text: modelData.text
                            checked: transactions.kind === modelData.value
                            onClicked: transactions.kind = modelData.value
                        }
                    }
                }
            }

            // Phones: the totals of what the list shows, as two tiles.
            RowLayout {
                Layout.fillWidth: true
                visible: page.phone && list.count > 0
                spacing: Kirigami.Units.largeSpacing

                Repeater {
                    model: [
                        { name: i18n("Income"), value: transactions.totalIncome, color: Kirigami.Theme.positiveTextColor, icon: "go-down-symbolic" },
                        { name: i18n("Expenses"), value: Math.abs(transactions.totalExpense), color: Kirigami.Theme.negativeTextColor, icon: "go-up-symbolic" }
                    ]
                    delegate: Rectangle {
                        id: total
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: totalRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                        radius: UI.Tokens.radiusInner
                        color: UI.Tokens.tint(Kirigami.Theme.backgroundColor, total.modelData.color, UI.Tokens.tintChip)

                        RowLayout {
                            id: totalRow
                            anchors {
                                fill: parent
                                margins: Kirigami.Units.largeSpacing
                            }
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: total.modelData.icon
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                isMask: true
                                color: total.modelData.color
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: total.modelData.name
                                    elide: Text.ElideRight
                                    font: Kirigami.Theme.smallFont
                                }
                                MoneyLabel {
                                    Layout.fillWidth: true
                                    value: total.modelData.value
                                    color: total.modelData.color
                                    font.weight: Font.Bold
                                    fontSizeMode: Text.HorizontalFit
                                    minimumPointSize: Kirigami.Theme.defaultFont.pointSize * 0.7
                                }
                            }
                        }
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: !page.phone && list.count > 0
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                elide: Text.ElideRight
                text: i18n("Income %1 · Expenses %2",
                           Config.privacyMode ? Money.masked : Money.format(transactions.totalIncome),
                           Config.privacyMode ? Money.masked : Money.format(transactions.totalExpense))
            }
        }
        background: Rectangle {
            // Phones: flat, in the page's color.
            color: page.phone ? Kirigami.Theme.backgroundColor : Kirigami.Theme.alternateBackgroundColor
            Kirigami.Separator {
                visible: !page.phone
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
            }
        }
    }

    TransactionDialog {
        id: transactionDialog
    }

    // Phones: the months of the month chip.
    UI.Menu {
        id: monthMenu

        Instantiator {
            model: [{ text: i18n("All months"), value: "" }].concat(FinanceSummary.months)
            delegate: QQC2.MenuItem {
                required property var modelData
                text: modelData.text
                onTriggered: transactions.month = modelData.value
            }
            onObjectAdded: (index, object) => monthMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => monthMenu.removeItem(object)
        }
    }

    Component {
        id: desktopRow
        UI.ListRow {
            id: delegate
            required property var model
            required property int index

            width: ListView.view.width
            onClicked: transactionDialog.openFor(transactions, transactions.get(index))
            contentItem: TransactionContent {
                description: delegate.model.description
                categoryLabel: delegate.model.categoryLabel
                categoryIcon: delegate.model.categoryIcon
                accountName: delegate.model.accountName
                installment: delegate.model.installment
                amount: delegate.model.amount
                currency: delegate.model.currency
                pending: delegate.model.pending
                internal: delegate.model.internal
                showAccount: page.accountId.length === 0
            }
        }
    }

    // Phones: round category icon (green for money in, grey between the
    // user's own accounts), bold description, the amount with its state below.
    Component {
        id: phoneRow
        UI.ListRow {
            id: row
            required property var model
            required property int index

            width: ListView.view.width
            leftPadding: Kirigami.Units.gridUnit
            rightPadding: Kirigami.Units.gridUnit
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            onClicked: transactionDialog.openFor(transactions, transactions.get(index))

            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                opacity: row.model.pending ? 0.75 : 1

                UI.IconBadge {
                    source: row.model.internal ? "exchange-positions" : row.model.categoryIcon
                    tint: row.model.internal ? Kirigami.Theme.disabledTextColor
                        : row.model.amount > 0.005 ? Kirigami.Theme.positiveTextColor
                        : Kirigami.Theme.highlightColor
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: row.model.description
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: [
                            row.model.internal ? i18n("Between your accounts") : row.model.categoryLabel,
                            page.accountId.length === 0 ? row.model.accountName : ""
                        ].filter(part => part && part.length > 0).join(" · ")
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
                ColumnLayout {
                    spacing: 0
                    MoneyLabel {
                        Layout.alignment: Qt.AlignRight
                        value: row.model.amount
                        currency: row.model.currency
                        signed: true
                        colored: !row.model.internal
                        font.weight: Font.DemiBold
                        opacity: row.model.internal ? 0.55 : 1
                    }
                    QQC2.Label {
                        Layout.alignment: Qt.AlignRight
                        visible: text.length > 0
                        text: row.model.pending ? i18n("pending")
                            : row.model.installment.length > 0 ? i18n("installment %1", row.model.installment)
                            : ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }
        }
    }

    ListView {
        id: list

        model: TransactionsModel {
            id: transactions
            accountId: page.accountId
        }

        section.property: "dateLabel"
        section.delegate: UI.SectionHeader {}

        onAtYEndChanged: {
            if (atYEnd && transactions.canLoadMore) {
                transactions.loadMore();
            }
        }

        delegate: page.phone ? phoneRow : desktopRow

        UI.EmptyState {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: list.count === 0
            icon.name: transactions.searchText.length > 0 ? "edit-find" : "view-financial-list"
            text: transactions.searchText.length > 0 || transactions.month.length > 0 ? i18n("No matching transactions") : i18n("No transactions")
            explanation: transactions.searchText.length > 0 || transactions.month.length > 0
                ? i18n("Try another search or month.")
                : i18n("Transactions appear here after a sync.")
        }
    }
}
