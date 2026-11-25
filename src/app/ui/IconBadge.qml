// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// An icon inside a tinted circle (phone list rows and tiles).
Rectangle {
    id: badge

    property alias source: icon.source
    property color tint: Kirigami.Theme.highlightColor

    implicitWidth: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.largeSpacing * 2
    implicitHeight: implicitWidth
    radius: width / 2
    color: Tokens.tint(Kirigami.Theme.backgroundColor, tint, Tokens.tintBadge)
    Accessible.ignored: true

    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        // The theme's own size: scaled icons come out blurry.
        width: Kirigami.Units.iconSizes.smallMedium
        height: width
        isMask: true
        // Toward the text color, so the icon reads on light and dark circles.
        color: Kirigami.ColorUtils.linearInterpolation(badge.tint, Kirigami.Theme.textColor, 0.45)
    }
}
