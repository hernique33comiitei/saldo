// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami
import org.saldo.core

// The overview with nothing to show yet: what to do next (set up Meu Pluggy,
// wait for the first sync, or sync).
Kirigami.PlaceholderMessage {
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
