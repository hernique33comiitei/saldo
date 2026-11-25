// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// Phones: the buttons Kirigami draws itself in the app's chrome (each page
// header's actions, back button and overflow menu, the drawer's ☰ handle)
// get the design system's round pressed state instead of Breeze's framed
// one. Headers are built per page and their buttons lazily, so this runs
// again after every page change and width change. Nothing on the desktop.
QtObject {
    id: chrome

    property Kirigami.ApplicationWindow window

    function restyle() {
        if (!Platform.isPhone || !window) {
            return;
        }
        const page = window.pageStack.currentItem;
        roundToolButtons(page ? page.globalToolBarItem : null);
        roundToolButtons(window.globalDrawer ? window.globalDrawer.handle : null);
    }

    function roundToolButtons(item) {
        if (!item) {
            return;
        }
        if (item instanceof T.ToolButton) {
            if (item.objectName !== "saldoRound") {
                item.objectName = "saldoRound";
                item.background = roundBackground.createObject(item, { control: item });
            }
            return;
        }
        for (const child of item.children) {
            roundToolButtons(child);
        }
    }

    property Component roundBackground: Component {
        RoundButtonBackground {}
    }

    // A few passes after each change: the header's buttons come late.
    property Timer passes: Timer {
        property int left: 0
        interval: 150
        repeat: true
        onTriggered: {
            chrome.restyle();
            if (--left <= 0) {
                stop();
            }
        }
    }
    function scheduleRestyle() {
        passes.left = 4;
        passes.restart();
    }

    property Connections pageChanges: Connections {
        target: Platform.isPhone && chrome.window ? chrome.window.pageStack : null
        function onCurrentItemChanged() {
            chrome.scheduleRestyle();
        }
    }
    property Connections widthChanges: Connections {
        target: Platform.isPhone ? chrome.window : null
        function onWidthChanged() {
            chrome.scheduleRestyle();
        }
    }

    Component.onCompleted: scheduleRestyle()
}
