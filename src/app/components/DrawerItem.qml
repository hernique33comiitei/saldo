// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Phones: one entry of the drawer, as a pill (highlighted while its page is
// open).
QQC2.ItemDelegate {
    id: item

    property string iconName
    property bool active: false

    Layout.fillWidth: true
    implicitHeight: Kirigami.Units.gridUnit * 2.75
    leftPadding: Kirigami.Units.gridUnit
    rightPadding: Kirigami.Units.gridUnit
    Accessible.name: text

    background: Rectangle {
        radius: height / 2
        color: item.active ? Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.28)
             : item.down ? Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)
             : "transparent"
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: item.iconName
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: item.text
            font.weight: item.active ? Font.Bold : Font.Normal
            elide: Text.ElideRight
        }
    }
}
