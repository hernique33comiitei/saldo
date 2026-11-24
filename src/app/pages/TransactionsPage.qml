// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

RefreshablePage {
    id: page

    // Optional: only this account's transactions.
    property string accountId: ""

    title: i18n("Transactions")

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
        padding: Kirigami.Units.largeSpacing
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.SearchField {
                    id: search
                    width: Math.min(Kirigami.Units.gridUnit * 16, parent.width)
                    delaySearch: true
                    onAccepted: transactions.searchText = text
                }
                QQC2.ComboBox {
                    id: monthBox
                    model: [{ text: i18n("All months"), value: "" }].concat(FinanceSummary.months)
                    textRole: "text"
                    valueRole: "value"
                    onActivated: transactions.month = currentValue
                    // The list is rebuilt (newest first) whenever the summary
                    // reloads; stay on the month the list is filtered by.
                    onModelChanged: Qt.callLater(() => currentIndex = Math.max(0, indexOfValue(transactions.month)))
                }
                QQC2.ComboBox {
                    id: kindBox
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

            QQC2.Label {
                Layout.fillWidth: true
                visible: list.count > 0
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                elide: Text.ElideRight
                text: i18n("Income %1 · Expenses %2",
                           Config.privacyMode ? Money.masked : Money.format(transactions.totalIncome),
                           Config.privacyMode ? Money.masked : Money.format(transactions.totalExpense))
            }
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

    TransactionDialog {
        id: transactionDialog
    }

    ListView {
        id: list

        model: TransactionsModel {
            id: transactions
            accountId: page.accountId
        }

        section.property: "dateLabel"
        section.delegate: Kirigami.ListSectionHeader {
            required property string section
            width: ListView.view.width
            text: section
        }

        onAtYEndChanged: {
            if (atYEnd && transactions.canLoadMore) {
                transactions.loadMore();
            }
        }

        delegate: QQC2.ItemDelegate {
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

        Kirigami.PlaceholderMessage {
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
