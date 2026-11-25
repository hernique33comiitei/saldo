// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// Phones: a pill-shaped button background, filled with the highlight color
// (Primary), tinted (Secondary) or bare (Flat). UI.Button's, and the dialog
// buttons' in a UI.Sheet.
Rectangle {
    property T.AbstractButton control
    property int variant: Button.Secondary

    implicitHeight: Tokens.buttonHeight
    implicitWidth: Tokens.buttonHeight
    radius: height / 2
    opacity: control && !control.enabled ? 0.5 : 1
    color: {
        const down = control && control.down;
        if (variant === Button.Primary) {
            return down ? Qt.darker(Kirigami.Theme.highlightColor, 1.15) : Kirigami.Theme.highlightColor;
        }
        const amount = variant === Button.Flat ? (down ? Tokens.tintPressed : 0)
                                               : (down ? Tokens.tintSelected : Tokens.tintChip);
        return amount > 0 ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, amount) : "transparent";
    }
}
