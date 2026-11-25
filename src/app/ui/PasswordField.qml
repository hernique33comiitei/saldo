// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// A secret field with its show/hide button. Desktop: Kirigami's own. Phones:
// filled and rounded like UI.TextField (the right padding stays Kirigami's:
// it makes room for the button).
Kirigami.PasswordField {
    id: field

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = fieldBackground.createObject(field);
            // Kirigami only makes room on the side of its show/hide button.
            leftPadding = Kirigami.Units.largeSpacing * 1.5;
            topPadding = Kirigami.Units.largeSpacing;
            bottomPadding = Kirigami.Units.largeSpacing;
        }
    }
    Component {
        id: fieldBackground
        FieldBackground {
            control: field
        }
    }
}
