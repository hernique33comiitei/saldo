// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// Phones: the filled, rounded background of a text field, a select or a
// number field, outlined while focused (UI.TextField, UI.Select…). A hairline
// keeps it apart from a card's own tint (a fill alone vanished on cards).
Rectangle {
    property Item control
    property bool pill: false
    property bool error: false

    implicitHeight: Tokens.fieldHeight
    implicitWidth: Kirigami.Units.gridUnit * 8
    radius: pill ? height / 2 : Tokens.radiusInner
    readonly property bool emphasized: error || (control && control.activeFocus)
    color: Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintField)
    border.width: emphasized ? Tokens.focusBorder : 1
    border.color: error ? Kirigami.Theme.negativeTextColor
                : emphasized ? Kirigami.Theme.highlightColor
                : Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintChip)
    opacity: control && !control.enabled ? 0.5 : 1
}
