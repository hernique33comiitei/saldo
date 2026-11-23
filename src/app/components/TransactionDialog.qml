// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

// Details of one transaction, with the switch that decides whether it is a
// movement between the user's own accounts (not counted as income/expense).
Kirigami.Dialog {
    id: dialog

    // TransactionsModel the row came from, and a copy of the row (its roles).
    property var transactions
    property var tx: ({})

    function openFor(transactionsModel, row) {
        transactions = transactionsModel;
        tx = row;
        open();
    }

    title: tx.description ?? ""
    standardButtons: Kirigami.Dialog.Close
    // Our own button texts: Qt's come from the platform (KDE's in Plasma) in
    // the system's language, not the app's.
    onAboutToShow: standardButton(Kirigami.Dialog.Close).text = i18n("Close")
    preferredWidth: Kirigami.Units.gridUnit * 24
    padding: Kirigami.Units.largeSpacing

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        MoneyLabel {
            Layout.alignment: Qt.AlignHCenter
            value: dialog.tx.amount ?? 0
            currency: dialog.tx.currency ?? "BRL"
            signed: true
            colored: !(dialog.tx.internal ?? false)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
            font.weight: Font.DemiBold
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.Label {
                Kirigami.FormData.label: i18n("Date:")
                text: dialog.tx.dateLabel ?? ""
            }
            QQC2.Label {
                Kirigami.FormData.label: i18n("Account:")
                text: dialog.tx.accountName ?? ""
            }
            QQC2.Label {
                Kirigami.FormData.label: i18n("Category:")
                text: dialog.tx.categoryLabel ?? ""
            }
            QQC2.Label {
                visible: (dialog.tx.counterparty ?? "").length > 0
                Kirigami.FormData.label: (dialog.tx.amount ?? 0) < 0 ? i18n("To:") : i18n("From:")
                text: dialog.tx.counterparty ?? ""
            }
            QQC2.Label {
                visible: (dialog.tx.installment ?? "").length > 0
                Kirigami.FormData.label: i18n("Installment:")
                text: dialog.tx.installment ?? ""
            }
            QQC2.Label {
                visible: dialog.tx.pending ?? false
                Kirigami.FormData.label: i18n("Status:")
                text: i18n("Pending")
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        QQC2.Switch {
            Layout.fillWidth: true
            text: i18n("Transfer between my accounts")
            checked: dialog.tx.internal ?? false
            onToggled: {
                dialog.transactions.setInternal(dialog.tx.transactionId, checked ? 1 : 0);
                dialog.tx = Object.assign({}, dialog.tx, {
                    internal: checked,
                    internalManual: true,
                    internalReason: checked ? i18n("You marked it as a transfer between your accounts.")
                                            : i18n("You marked it to count as income or expense.")
                });
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: (dialog.tx.internal ?? false)
                  ? i18n("Not counted as income or expense: the money only moved between your accounts.")
                  : i18n("Counted as income or expense.")
            wrapMode: Text.Wrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: (dialog.tx.internalReason ?? "").length > 0
            text: dialog.tx.internalReason ?? ""
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        QQC2.Button {
            visible: dialog.tx.internalManual ?? false
            text: i18n("Use Automatic Detection")
            icon.name: "edit-undo"
            onClicked: {
                dialog.transactions.setInternal(dialog.tx.transactionId, -1);
                dialog.close();
            }
        }
    }
}
