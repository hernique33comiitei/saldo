// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Picks one value from a list (a ComboBox). Desktop: the style's own, a menu
// under the box. Phones: a filled, rounded box whose options open in a
// bottom sheet, the current one checked.
QQC2.ComboBox {
    id: combo

    Component.onCompleted: {
        if (Platform.isPhone) {
            // The control's own delegate stays: replacing it reset the
            // current index (-1, an empty box). The sheet lists the options
            // with a delegate of its own.
            background = phoneBackground.createObject(combo);
            popup = phonePopup.createObject(combo);
            leftPadding = Kirigami.Units.largeSpacing * 1.5;
        }
    }

    Component {
        id: phoneBackground
        FieldBackground {
            control: combo
        }
    }

    Component {
        id: phoneDelegate
        QQC2.ItemDelegate {
            id: option
            required property int index

            width: ListView.view ? ListView.view.width : implicitWidth
            implicitHeight: Tokens.drawerItemHeight
            leftPadding: Kirigami.Units.gridUnit
            rightPadding: Kirigami.Units.gridUnit
            text: combo.textAt(index)
            // As the control does: select, tell the page (onActivated), close.
            onClicked: {
                combo.currentIndex = index;
                combo.activated(index);
                combo.popup.close();
            }
            background: Rectangle {
                radius: height / 2
                color: option.index === combo.currentIndex
                       ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, Tokens.tintActive)
                       : option.down ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintPressed)
                       : "transparent"
            }
            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    text: option.text
                    elide: Text.ElideRight
                    font.weight: option.index === combo.currentIndex ? Font.Bold : Font.Normal
                }
                Kirigami.Icon {
                    visible: option.index === combo.currentIndex
                    source: "checkmark"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
            }
        }
    }

    Component {
        id: phonePopup
        QQC2.Popup {
            id: sheet
            parent: QQC2.Overlay.overlay
            modal: true
            x: 0
            width: parent ? parent.width : 0
            height: Math.min(implicitHeight, parent ? parent.height * 0.7 : implicitHeight)
            y: parent ? parent.height - height : 0
            topPadding: Kirigami.Units.gridUnit * 1.5
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing + (parent ? parent.SafeArea.margins.bottom : 0)
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false

            QQC2.Overlay.modal: Rectangle {
                color: Qt.rgba(0, 0, 0, Tokens.tintScrim)
            }
            enter: Transition {
                NumberAnimation {
                    property: "y"
                    from: sheet.parent ? sheet.parent.height : 0
                    to: sheet.parent ? sheet.parent.height - sheet.height : 0
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
            exit: Transition {
                NumberAnimation {
                    property: "y"
                    to: sheet.parent ? sheet.parent.height : 0
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.InCubic
                }
            }
            background: SheetBackground {}
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: sheet.visible ? combo.count : 0
                delegate: phoneDelegate
                spacing: Kirigami.Units.smallSpacing / 2
            }
        }
    }
}
