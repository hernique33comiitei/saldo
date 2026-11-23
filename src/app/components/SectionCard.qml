// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Card with a heading; children go into a column.
Kirigami.AbstractCard {
    id: card

    property string title
    property list<Kirigami.Action> headerActions
    default property alias content: column.data

    // Spacing rule of the app: page margins, card padding and gaps between
    // cards are all Kirigami.Units.gridUnit.
    padding: Kirigami.Units.gridUnit

    header: Item {
        implicitWidth: headerRow.implicitWidth
        // Only the title sets the height; header buttons overhang it a little
        // (into the padding), so cards with and without buttons keep their
        // titles on the same line.
        implicitHeight: heading.implicitHeight

        RowLayout {
            id: headerRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                id: heading
                Layout.fillWidth: true
                text: card.title
                level: 4
                elide: Text.ElideRight
            }
            // Plain buttons: an ActionToolBar sharing the row with a fill-width
            // heading collapsed into an overflow menu.
            Repeater {
                model: card.headerActions
                delegate: QQC2.ToolButton {
                    required property var modelData
                    action: modelData
                    display: QQC2.AbstractButton.TextBesideIcon
                }
            }
        }
    }

    // The column keeps its own height inside a wrapper: AbstractCard's
    // Control stretches contentItem to the whole card minus padding (header
    // not subtracted), and nested layouts would spread out to fill that,
    // pushing the last rows below the card's edge.
    contentItem: Item {
        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            width: parent.width
            spacing: Kirigami.Units.largeSpacing
        }
    }
}
