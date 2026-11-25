// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// A message in the page (information, success, warning, error), with optional
// actions. Desktop: Kirigami's InlineMessage. Phones: a rounded card tinted
// by the message type, no border.
Kirigami.InlineMessage {
    id: message

    readonly property color typeColor: type === Kirigami.MessageType.Positive ? Kirigami.Theme.positiveTextColor
                                     : type === Kirigami.MessageType.Warning ? Kirigami.Theme.neutralTextColor
                                     : type === Kirigami.MessageType.Error ? Kirigami.Theme.negativeTextColor
                                     : Kirigami.Theme.activeTextColor

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = phoneBackground.createObject(message);
            leftPadding = Kirigami.Units.largeSpacing * 1.5;
            rightPadding = Kirigami.Units.largeSpacing;
            topPadding = Kirigami.Units.largeSpacing;
            bottomPadding = Kirigami.Units.largeSpacing;
        }
    }
    Component {
        id: phoneBackground
        Rectangle {
            radius: message.position === Kirigami.InlineMessage.Inline ? Tokens.radiusInner : 0
            color: Tokens.tint(Kirigami.Theme.backgroundColor, message.typeColor, Tokens.tintBadge)
        }
    }
}
