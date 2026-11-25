// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Phones: a filter chip. `checked` only shows the state (the user of the chip
// sets it), so a binding to it is never broken by a click. `dropDown` shows an
// arrow instead of the check mark (the chip opens a menu).
QQC2.AbstractButton {
    id: chip

    property bool dropDown: false

    implicitWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 3
    implicitHeight: Math.max(row.implicitHeight + Kirigami.Units.smallSpacing * 2, Kirigami.Units.gridUnit * 2)
    Accessible.role: chip.dropDown ? Accessible.ButtonMenu : Accessible.CheckBox
    Accessible.checkable: !chip.dropDown
    Accessible.checked: chip.checked

    background: Rectangle {
        radius: height / 2
        color: chip.checked ? Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.25)
             : chip.down ? Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)
             : "transparent"
        border.width: chip.checked ? 0 : 1
        border.color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.25)
    }

    contentItem: Item {
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                visible: chip.checked && !chip.dropDown
                source: "checkmark"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                isMask: true
                color: Kirigami.Theme.textColor
            }
            QQC2.Label {
                text: chip.text
                font.weight: chip.checked ? Font.DemiBold : Font.Normal
            }
            Kirigami.Icon {
                visible: chip.dropDown
                source: "arrow-down"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
    }
}
