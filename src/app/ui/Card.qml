// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A card with a title; children go into a column.
// Desktop: Kirigami's card, its header actions as tool buttons.
// Phones: borderless on a tonal surface, a bold title, and the first header
// action as a link at its right ("Cards ›").
Kirigami.AbstractCard {
    id: card

    property string title
    property list<Kirigami.Action> headerActions
    default property alias content: column.data

    // Spacing rule of the app: page margins, card padding and gaps between
    // cards are all Kirigami.Units.gridUnit.
    padding: Kirigami.Units.gridUnit

    // Phones only, so the desktop keeps the style's card untouched.
    Component.onCompleted: {
        // No title and no actions (a phone tile): no header at all; AbstractCard
        // adds a gap under any header, even an invisible one.
        if (title.length === 0 && headerActions.length === 0) {
            header = null;
        }
        if (Platform.isPhone) {
            background = phoneBackground.createObject(card);
            heading.font.weight = Font.Bold;
            heading.font.pointSize = Kirigami.Theme.defaultFont.pointSize * Tokens.fontTitle;
        }
    }

    Component {
        id: phoneBackground
        Rectangle {
            radius: Tokens.radiusCard
            color: Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintSurface)
        }
    }

    header: Item {
        // No title and no actions (a phone tile): no empty header row.
        visible: card.title.length > 0 || card.headerActions.length > 0
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
                model: Platform.isPhone ? [] : card.headerActions
                delegate: QQC2.ToolButton {
                    required property var modelData
                    action: modelData
                    display: QQC2.AbstractButton.TextBesideIcon
                }
            }
            // Phones: the first action as a link; its finger-sized target
            // overhangs the title row, which keeps the title's height.
            Item {
                visible: Platform.isPhone && card.headerActions.length > 0
                implicitWidth: link.implicitWidth
                implicitHeight: heading.implicitHeight

                QQC2.AbstractButton {
                    id: link
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: linkRow.implicitWidth
                    implicitHeight: Tokens.touchTarget
                    text: card.headerActions.length > 0 ? card.headerActions[0].text : ""
                    onClicked: card.headerActions[0].trigger()
                    background: null
                    contentItem: RowLayout {
                        id: linkRow
                        spacing: Kirigami.Units.smallSpacing
                        QQC2.Label {
                            text: link.text
                            color: Kirigami.Theme.linkColor
                            font.weight: Font.DemiBold
                        }
                        Kirigami.Icon {
                            source: "go-next-symbolic"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                            isMask: true
                            color: Kirigami.Theme.linkColor
                        }
                    }
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
