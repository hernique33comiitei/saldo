// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

// Names a connection ("Nubank"). Pluggy calls every Meu Pluggy item
// "MeuPluggy", so this is how the user tells banks apart.
Kirigami.PromptDialog {
    id: dialog

    property string itemId
    property string accountsSummary

    function openFor(itemId: string, currentName: string, accountsSummary: string) {
        dialog.itemId = itemId;
        dialog.accountsSummary = accountsSummary;
        nameField.text = currentName;
        open();
        nameField.forceActiveFocus();
        nameField.selectAll();
    }

    title: i18n("Name This Connection")
    standardButtons: Kirigami.Dialog.Save | Kirigami.Dialog.Cancel
    onAccepted: Config.setItemName(itemId, nameField.text)

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            text: dialog.accountsSummary.length > 0
                  ? i18n("Accounts in this connection: %1", dialog.accountsSummary)
                  : i18n("Its accounts show up here after the first sync.")
            wrapMode: Text.Wrap
            opacity: 0.8
        }
        QQC2.TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: i18nc("example name for a bank connection", "e.g. Nubank")
            onAccepted: dialog.accept()
        }
    }
}
