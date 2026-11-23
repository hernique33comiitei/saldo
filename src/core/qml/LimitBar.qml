// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// Horizontal meter for how much of a limit is used (green → yellow → red).
Item {
    id: bar

    property real ratio: 0
    readonly property real clampedRatio: Math.max(0, Math.min(1, ratio))
    readonly property color usageColor: ratio >= 0.8 ? Kirigami.Theme.negativeTextColor
                                      : ratio >= 0.5 ? Kirigami.Theme.neutralTextColor
                                      : Kirigami.Theme.positiveTextColor

    implicitWidth: Kirigami.Units.gridUnit * 8
    implicitHeight: Math.round(Kirigami.Units.smallSpacing * 1.5)

    Accessible.role: Accessible.ProgressBar
    Accessible.name: i18nd("saldo", "%1% used", Math.round(clampedRatio * 100))

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
    }

    Rectangle {
        width: Math.max(height, parent.width * bar.clampedRatio)
        height: parent.height
        visible: bar.clampedRatio > 0
        radius: height / 2
        color: bar.usageColor

        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
