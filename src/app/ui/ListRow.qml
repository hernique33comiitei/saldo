// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A tappable row (a list's delegate, a link in a card). Desktop: the style's
// ItemDelegate. Phones: no background of its own (it sat as a white band on
// cards) and the design system's pressed tint instead of Breeze's highlight.
QQC2.ItemDelegate {
    id: row

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = phoneBackground.createObject(row);
        }
    }
    Component {
        id: phoneBackground
        Rectangle {
            radius: Tokens.radiusInner
            color: row.down || row.highlighted
                   ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintPressed)
                   : "transparent"
        }
    }
}
