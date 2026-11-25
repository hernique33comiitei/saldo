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
            background = roundBackground.createObject(button, { control: button });
        }
    }
    Component {
        id: roundBackground
        RoundButtonBackground {}
    }
}
