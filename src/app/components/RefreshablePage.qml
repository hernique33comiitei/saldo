// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami
import org.saldo.core

// A main page with pull-to-refresh on phones: pulling the page down syncs,
// like its Refresh action, and the spinner stays until the sync ends.
Kirigami.ScrollablePage {
    id: page

    supportsRefreshing: Kirigami.Settings.isMobile && Credentials.configured && Config.itemIds.length > 0
    onRefreshingChanged: {
        if (!refreshing) {
            return;
        }
        SyncManager.sync();
        if (!SyncManager.running) {
            refreshing = false; // nothing started
        }
    }

    Connections {
        target: SyncManager
        function onRunningChanged() {
            if (!SyncManager.running) {
                page.refreshing = false;
            }
        }
    }
}
