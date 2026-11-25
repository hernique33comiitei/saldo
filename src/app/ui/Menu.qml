// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A popup menu. Desktop: the style's own. Phones: rounded, on the pages'
// surface color.
QQC2.Menu {
    id: menu

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = phoneBackground.createObject(menu.contentItem ? menu.contentItem.parent : null);
        }
    }
    Component {
        id: phoneBackground
        Rectangle {
            implicitWidth: Kirigami.Units.gridUnit * 12
            radius: Tokens.radiusInner
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintChip)
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false
        }
    }
}
