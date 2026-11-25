// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// An on/off switch. Desktop: the style's own. Phones: a larger track in the
// highlight color when on, its thumb sliding (as Android's).
QQC2.Switch {
    id: control

    Component.onCompleted: {
        if (Platform.isPhone) {
            indicator = phoneIndicator.createObject(control);
        }
    }
    Component {
        id: phoneIndicator
        Rectangle {
            x: control.text.length > 0
               ? (control.mirrored ? control.width - width - control.rightPadding : control.leftPadding)
               : Math.round((control.width - width) / 2)
            y: control.topPadding + Math.round((control.availableHeight - height) / 2)
            implicitWidth: Tokens.switchWidth
            implicitHeight: Tokens.switchHeight
            radius: height / 2
            opacity: control.enabled ? 1 : 0.5
            color: control.checked ? Kirigami.Theme.highlightColor
                                   : Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintSwitchOff)

            Rectangle {
                readonly property real inset: Math.round(parent.height * 0.15)
                width: parent.height - inset * 2
                height: width
                radius: width / 2
                y: inset
                x: control.checked ? parent.width - width - inset : inset
                color: control.checked ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.backgroundColor
                Behavior on x {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
