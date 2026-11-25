// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Phones: a borderless card on a tonal surface, SectionCard's counterpart.
// Children go into a column; an optional title (and a link at its right) sit
// on top.
QQC2.Control {
    id: card

    property string title
    // Text of a link at the title's right, e.g. "Cards"; emits actionTriggered().
    property string actionText
    default property alias content: column.data

    signal actionTriggered()

    padding: Kirigami.Units.gridUnit

    background: Rectangle {
        radius: Kirigami.Units.gridUnit
        color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.06)
    }

    // The column keeps its own height inside a wrapper (see SectionCard).
    contentItem: Item {
        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                visible: card.title.length > 0
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    id: heading
                    Layout.fillWidth: true
                    text: card.title
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    elide: Text.ElideRight
                    Accessible.role: Accessible.Heading
                }
                // Only the title sets the row's height; the link's finger-sized
                // target overhangs it, as SectionCard's header buttons do.
                Item {
                    visible: card.actionText.length > 0
                    implicitWidth: link.implicitWidth
                    implicitHeight: heading.implicitHeight

                    QQC2.AbstractButton {
                        id: link
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        implicitWidth: linkRow.implicitWidth
                        implicitHeight: Kirigami.Units.gridUnit * 2
                        text: card.actionText
                        onClicked: card.actionTriggered()
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
    }
}
