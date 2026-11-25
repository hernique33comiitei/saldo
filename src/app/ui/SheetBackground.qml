// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// Phones: the background of a bottom sheet (UI.Sheet, UI.Select's options):
// rounded on top, with a handle.
Rectangle {
    // The handle's area, for dragging the sheet down (UI.Sheet).
    readonly property alias handle: handleArea

    color: Kirigami.Theme.backgroundColor
    topLeftRadius: Tokens.radiusHero
    topRightRadius: Tokens.radiusHero

    Item {
        id: handleArea
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Kirigami.Units.gridUnit * 1.5

        Rectangle {
            anchors.centerIn: parent
            width: Tokens.sheetHandleWidth
            height: Tokens.sheetHandleHeight
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: 0.3
        }
    }
}
