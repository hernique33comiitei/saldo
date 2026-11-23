// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.saldo.core

PlasmoidItem {
    id: root

    readonly property string compactDisplay: Plasmoid.configuration.compactDisplay
    readonly property bool showInvestments: Plasmoid.configuration.showInvestments
    readonly property bool needsAttention: FinanceSummary.attention.length > 0 || SyncManager.lastError.length > 0

    function amount(value) {
        return Config.privacyMode ? Money.masked : Money.format(value);
    }

    Plasmoid.icon: "saldo"
    Plasmoid.status: needsAttention ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus

    // On the desktop, show the full view directly when there is room.
    switchWidth: Kirigami.Units.gridUnit * 18
    switchHeight: Kirigami.Units.gridUnit * 18

    toolTipMainText: i18nd("saldo", "Saldo")
    toolTipSubText: {
        if (!Credentials.configured) {
            return i18nd("saldo", "Not set up: open Saldo to connect Meu Pluggy");
        }
        if (SyncManager.running) {
            return SyncManager.progressText;
        }
        if (!FinanceSummary.hasData) {
            return i18nd("saldo", "No data yet");
        }
        const parts = [i18nd("saldo", "Accounts %1", amount(FinanceSummary.totalCash))];
        if (FinanceSummary.cardLimit > 0) {
            parts.push(i18nd("saldo", "cards %1 used", Money.percent(FinanceSummary.cardUsedRatio)));
        }
        parts.push(i18nd("saldo", "checked %1", Money.relativeTime(SyncManager.lastSyncAt)));
        let text = parts.join(" · ");
        if (needsAttention) {
            text += "\n" + (SyncManager.lastError.length > 0 ? SyncManager.lastError : FinanceSummary.attention[0]);
        }
        return text + "\n" + i18nd("saldo", "Middle-click to hide or show values");
    }

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nd("saldo", "Refresh")
            icon.name: "view-refresh"
            enabled: Credentials.configured && !SyncManager.running
            onTriggered: SyncManager.sync()
        },
        PlasmaCore.Action {
            text: Config.privacyMode ? i18nd("saldo", "Show Values") : i18nd("saldo", "Hide Values")
            icon.name: Config.privacyMode ? "view-visible" : "view-hidden"
            onTriggered: Config.privacyMode = !Config.privacyMode
        },
        PlasmaCore.Action {
            text: i18nd("saldo", "Open Saldo")
            icon.name: "saldo"
            visible: Launcher.canOpenApp
            onTriggered: Launcher.openApp("")
        }
    ]

    Component.onCompleted: SyncManager.syncIfStale()
    onExpandedChanged: {
        if (root.expanded) {
            SyncManager.syncIfStale();
        }
    }
}
