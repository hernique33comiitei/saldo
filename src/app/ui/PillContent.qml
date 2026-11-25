// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// Phones: a pill button's icon and text, colored by its variant (see
// PillBackground).
Item {
    id: content

    property T.AbstractButton control
    property int variant: Button.Secondary
    readonly property color textColor: variant === Button.Primary ? Kirigami.Theme.highlightedTextColor
                                     : variant === Button.Flat ? Kirigami.Theme.linkColor
                                     : Kirigami.Theme.textColor

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    opacity: control && !control.enabled ? 0.6 : 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            visible: content.control && content.control.icon.name.length > 0
                     && content.control.display !== T.AbstractButton.TextOnly
            source: content.control ? content.control.icon.name : ""
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            isMask: true
            color: content.textColor
        }
        QQC2.Label {
            visible: content.control && content.control.text.length > 0
                     && content.control.display !== T.AbstractButton.IconOnly
            text: content.control ? content.control.text.replace("&", "") : ""
            color: content.textColor
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}
