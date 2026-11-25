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
            centerIcon();
        }
    }

    // Phones: the icon centered on the text even when it wraps (Kirigami
    // pins it to the top from two lines on, a little above the first line);
    // still at the top when the actions sit below the text.
    function centerIcon() {
        const layout = contentItem;
        for (const child of layout ? layout.children : []) {
            if (child instanceof Kirigami.Icon && child.states.length > 0) {
                child.states[0].when = Qt.binding(() => layout.atBottom === true);
                return;
            }
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
