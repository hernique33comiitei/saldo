// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// Phones: the filled, rounded background of a text field, a select or a
// number field, outlined while focused (UI.TextField, UI.Select…).
Rectangle {
    property Item control
    property bool pill: false
    property bool error: false

    implicitHeight: Tokens.fieldHeight
    implicitWidth: Kirigami.Units.gridUnit * 8
    radius: pill ? height / 2 : Tokens.radiusInner
    color: Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintSurface)
    border.width: error || (control && control.activeFocus) ? Tokens.focusBorder : 0
    border.color: error ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
    opacity: control && !control.enabled ? 0.5 : 1
}
