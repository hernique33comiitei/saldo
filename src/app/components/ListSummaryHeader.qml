// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// The summary above a list page (total in accounts, overall limit, total
// invested): a band with a separator on the desktop, a tonal card on the
// page's own color on phones. Children go into a column.
QQC2.Control {
    id: band

    readonly property bool phone: Kirigami.Settings.isMobile
    default property alias content: column.data

    padding: Kirigami.Units.largeSpacing
    // Phones: the page's side margins. Set here, not bound, so the desktop
    // keeps the style's own paddings.
    Component.onCompleted: {
        if (phone) {
            leftPadding = Kirigami.Units.gridUnit;
            rightPadding = Kirigami.Units.gridUnit;
        }
    }

    contentItem: Item {
        readonly property real inset: band.phone ? Kirigami.Units.largeSpacing * 1.5 : 0

        implicitWidth: column.implicitWidth + inset * 2
        implicitHeight: column.implicitHeight + inset * 2

        Rectangle {
            anchors.fill: parent
            visible: band.phone
            radius: Kirigami.Units.gridUnit
            color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.06)
        }
        ColumnLayout {
            id: column
            anchors {
                fill: parent
                margins: parent.inset
            }
            spacing: Kirigami.Units.smallSpacing
        }
    }

    background: Rectangle {
        color: band.phone ? Kirigami.Theme.backgroundColor : Kirigami.Theme.alternateBackgroundColor
        Kirigami.Separator {
            visible: !band.phone
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
        }
    }
}
