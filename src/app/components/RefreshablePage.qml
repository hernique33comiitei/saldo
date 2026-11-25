// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami
import org.saldo.core

// A main page with pull-to-refresh on phones: pulling the page down syncs,
// like its Refresh action, and the spinner stays until the sync ends.
Kirigami.ScrollablePage {
    id: page

    // Phones: a large bold title in the header (PhoneTitle), and the View
    // colors, which the header, the tabs and the drawer share there (list
    // pages took them and the others the Window ones: two greys).
    Component.onCompleted: {
        if (Kirigami.Settings.isMobile) {
            titleDelegate = phoneTitle;
            Kirigami.Theme.colorSet = Kirigami.Theme.View;
        }
    }
    Component {
        id: phoneTitle
        PhoneTitle {
            text: page.title
        }
    }

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
