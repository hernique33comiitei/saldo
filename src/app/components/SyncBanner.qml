// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI
import org.saldo.core

// Page header with sync progress, sync errors and connection warnings.
ColumnLayout {
    id: banner

    spacing: 0

    UI.Banner {
        Layout.fillWidth: true
        position: Kirigami.InlineMessage.Header
        type: Kirigami.MessageType.Information
        visible: SyncManager.running
        text: SyncManager.progressText.length > 0 ? SyncManager.progressText : i18n("Syncing with Pluggy…")
    }

    UI.Banner {
        Layout.fillWidth: true
        position: Kirigami.InlineMessage.Header
        type: Kirigami.MessageType.Error
        visible: !SyncManager.running && SyncManager.lastError.length > 0
        text: SyncManager.lastError
        actions: [
            Kirigami.Action {
                text: i18n("Settings")
                icon.name: "configure"
                onTriggered: applicationWindow().showPage("settings")
            },
            Kirigami.Action {
                text: i18n("Dismiss")
                icon.name: "dialog-ok-apply"
                onTriggered: SyncManager.dismissError()
            }
        ]
    }

    Repeater {
        model: FinanceSummary.attention
        delegate: UI.Banner {
            required property string modelData
            Layout.fillWidth: true
            position: Kirigami.InlineMessage.Header
            type: Kirigami.MessageType.Warning
            visible: true
            text: modelData
        }
    }

    UI.Banner {
        Layout.fillWidth: true
        position: Kirigami.InlineMessage.Header
        type: Kirigami.MessageType.Warning
        visible: !Credentials.keyringAvailable
        text: Credentials.keyringUnavailableReason
    }
}
