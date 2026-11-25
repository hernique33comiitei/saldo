// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A push button. Desktop: the style's own, whatever the variant. Phones: a
// pill, filled with the highlight color (Primary), tinted (Secondary) or bare
// (Flat).
QQC2.Button {
    id: button

    enum Variant {
        Secondary,
        Primary,
        Flat
    }

    property int variant: Button.Secondary

    readonly property color phoneTextColor: variant === Button.Primary ? Kirigami.Theme.highlightedTextColor
                                          : variant === Button.Flat ? Kirigami.Theme.linkColor
                                          : Kirigami.Theme.textColor

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = phoneBackground.createObject(button);
            contentItem = phoneContent.createObject(button);
            leftPadding = Kirigami.Units.gridUnit;
            rightPadding = Kirigami.Units.gridUnit;
            topPadding = Kirigami.Units.smallSpacing;
            bottomPadding = Kirigami.Units.smallSpacing;
        }
    }

    Component {
        id: phoneBackground
        Rectangle {
            implicitHeight: Tokens.buttonHeight
            implicitWidth: Tokens.buttonHeight
            radius: height / 2
            opacity: button.enabled ? 1 : 0.5
            color: {
                if (button.variant === Button.Primary) {
                    return button.down ? Qt.darker(Kirigami.Theme.highlightColor, 1.15) : Kirigami.Theme.highlightColor;
                }
                const amount = button.variant === Button.Flat ? (button.down ? Tokens.tintPressed : 0)
                                                               : (button.down ? Tokens.tintSelected : Tokens.tintChip);
                return amount > 0 ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, amount) : "transparent";
            }
        }
    }
    Component {
        id: phoneContent
        Item {
            implicitWidth: row.implicitWidth
            implicitHeight: row.implicitHeight
            opacity: button.enabled ? 1 : 0.6
            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    visible: button.icon.name.length > 0 && button.display !== QQC2.AbstractButton.TextOnly
                    source: button.icon.name
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    isMask: true
                    color: button.phoneTextColor
                }
                QQC2.Label {
                    visible: button.text.length > 0 && button.display !== QQC2.AbstractButton.IconOnly
                    text: button.text
                    color: button.phoneTextColor
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }
    }
}
