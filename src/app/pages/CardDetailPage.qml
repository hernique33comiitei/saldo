// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

Kirigami.ScrollablePage {
    id: page

    property string accountId
    // Row of AccountsModel (see its roles). The caller passes the row it has
    // for a quick first paint; it is refreshed from `cards` after every reload.
    property var card: ({})

    AccountsModel {
        id: cards
        type: "CREDIT"
        onReloaded: {
            for (let i = 0; i < count; ++i) {
                const row = get(i);
                if (row.accountId === page.accountId) {
                    page.card = row;
                    return;
                }
            }
        }
    }

    readonly property bool wide: width > Kirigami.Units.gridUnit * 36
    readonly property bool hasLastBill: (card.lastBillTotal ?? 0) > 0 && (card.lastBillDueLabel ?? "").length > 0

    function amount(value) {
        return Config.privacyMode ? Money.masked : Money.format(value);
    }

    // "Label ........ value", like the rows of the overview cards.
    component InfoRow: RowLayout {
        property alias label: labelText.text
        property alias value: valueText.text
        property alias valueColor: valueText.color

        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            id: labelText
            Layout.fillWidth: true
            elide: Text.ElideRight
            opacity: 0.8
        }
        QQC2.Label {
            id: valueText
            font.features: { "tnum": 1 }
        }
    }

    // The headline amount of a bill card.
    component BigAmount: MoneyLabel {
        Layout.fillWidth: true
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    title: card.name ?? i18n("Credit Card")

    actions: [
        Kirigami.Action {
            text: i18n("Transactions")
            icon.name: "view-financial-list"
            onTriggered: applicationWindow().pageStack.push(transactionsComponent, {
                accountId: page.accountId,
                title: page.card.name
            })
        }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        // Which card, and how much of its limit is taken. Same wrapper as
        // SectionCard (keeps the column at its own height).
        Kirigami.AbstractCard {
            Layout.fillWidth: true
            padding: Kirigami.Units.gridUnit

            contentItem: Item {
                implicitWidth: limitColumn.implicitWidth
                implicitHeight: limitColumn.implicitHeight

                ColumnLayout {
                    id: limitColumn
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing

                    CardContent {
                        Layout.fillWidth: true
                        name: page.card.name ?? ""
                        numberLabel: page.card.numberLabel ?? ""
                        cardLabel: page.card.cardLabel ?? ""
                        institution: page.card.institution ?? ""
                        limit: page.card.creditLimit ?? 0
                        used: page.card.usedCredit ?? 0
                        available: page.card.availableCreditLimit ?? 0
                        ratio: page.card.usedRatio ?? 0
                        sharedLimit: page.card.sharedLimit ?? false
                        included: Config.excludedCardIds.indexOf(page.accountId) < 0
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: (page.card.creditLimit ?? 0) > 0
                        text: i18n("“Used” is everything not paid yet, future installments included.")
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                    QQC2.Switch {
                        text: i18n("Count this card in the overall limit")
                        checked: Config.excludedCardIds.indexOf(page.accountId) < 0
                        onToggled: Config.setCardIncluded(page.accountId, checked)
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: page.wide ? 2 : 1
            columnSpacing: Kirigami.Units.gridUnit
            rowSpacing: Kirigami.Units.gridUnit

            // Purchases not on any closed bill yet.
            SectionCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                title: i18n("Current bill (open)")

                BigAmount {
                    visible: page.card.billKnown ?? false
                    value: page.card.currentBill ?? 0
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: !(page.card.billKnown ?? false)
                    text: i18n("This institution does not tell which purchases are on the open bill.")
                    wrapMode: Text.Wrap
                    opacity: 0.7
                }
                InfoRow {
                    label: i18n("Closes around")
                    value: page.card.currentBillCloseLabel || "—"
                }
                InfoRow {
                    label: i18n("Due around")
                    value: page.card.currentBillDueLabel || "—"
                }
            }

            SectionCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                visible: page.hasLastBill
                title: i18n("Last closed bill")

                BigAmount {
                    value: page.card.lastBillTotal ?? 0
                }
                InfoRow {
                    label: i18n("Due on")
                    value: page.card.lastBillDueLabel ?? ""
                }
                InfoRow {
                    label: i18n("Minimum payment")
                    value: page.amount(page.card.minimumPayment ?? 0)
                }
                InfoRow {
                    label: i18n("Status")
                    value: (page.card.lastBillPaid ?? false) ? i18n("Paid")
                         : (page.card.lastBillOverdue ?? false) ? i18n("No payment found yet")
                         : i18n("%1 still to pay", page.amount(page.card.closedToPay ?? 0))
                    valueColor: (page.card.lastBillPaid ?? false) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                }
            }
        }

        SectionCard {
            Layout.fillWidth: true
            title: i18n("Previous bills")

            Repeater {
                model: BillsModel {
                    id: bills
                    accountId: page.accountId
                }
                delegate: ColumnLayout {
                    id: billRow
                    required property var model

                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: billRow.model.monthLabel
                            elide: Text.ElideRight
                        }
                        MoneyLabel {
                            value: billRow.model.totalAmount
                            currency: billRow.model.currency
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: Kirigami.Units.smallSpacing
                        Rectangle {
                            width: parent.width * (bills.maxValue > 0 ? billRow.model.totalAmount / bills.maxValue : 0)
                            height: parent.height
                            radius: height / 2
                            color: Kirigami.Theme.highlightColor
                            opacity: 0.6
                        }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18n("Closed %1 · due %2", billRow.model.closingLabel || "—", billRow.model.dueLabel || "—")
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: bills.count === 0
                text: i18n("This institution does not share past bills through Pluggy.")
                wrapMode: Text.Wrap
                opacity: 0.7
            }
        }
    }

    Component {
        id: transactionsComponent
        TransactionsPage {}
    }
}
