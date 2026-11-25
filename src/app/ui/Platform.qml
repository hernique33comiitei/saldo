// SPDX-License-Identifier: MIT
pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami

// Where the design system adapts: phones (Android) get its own look, the
// desktop the KDE controls untouched. The one place that decides.
QtObject {
    readonly property bool isPhone: Kirigami.Settings.isMobile

    // Where the on-screen keyboard starts, in an item's coordinates (a
    // sheet's parent: the window's overlay), or the item's height when no
    // keyboard is shown. Sheets sit on it, so a field in one stays above the
    // keyboard. Qt reports the keyboard in physical pixels on Android (720
    // wide in a 360 window); it spans the window's width, so the ratio of the
    // widths scales it.
    function keyboardTop(item: Item): real {
        if (!item) {
            return 0;
        }
        const rect = Qt.inputMethod.keyboardRectangle;
        if (!Qt.inputMethod.visible || rect.height <= 0 || rect.width <= 0 || item.width <= 0) {
            return item.height;
        }
        const scale = Math.max(1, rect.width / item.width);
        return Math.min(item.height, rect.y / scale);
    }
}
