// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

// The overview's last line: when Pluggy updated the banks, when it updates
// them next, and when Saldo last checked.
QQC2.Label {
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
