// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A tool button (usually icon-only, with a tooltip). Desktop: the style's
// own. Phones: a round, finger-sized target, tinted while pressed.
QQC2.ToolButton {
    id: button

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = phoneBackground.createObject(button);
        }
    }
    Component {
        id: phoneBackground
        Rectangle {
            implicitWidth: Tokens.touchTarget
            implicitHeight: Tokens.touchTarget
            radius: height / 2
            color: button.down || button.checked
                   ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintPressed)
                   : "transparent"
        }
    }
}
