// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// Phones: an icon button's background, a finger-sized circle tinted while
// pressed or checked. UI.IconButton's, and the close button of a UI.Sheet.
Rectangle {
    property T.AbstractButton control

    implicitWidth: Tokens.touchTarget
    implicitHeight: Tokens.touchTarget
    radius: height / 2
    color: control && (control.down || control.checked)
           ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintPressed)
           : "transparent"
}
