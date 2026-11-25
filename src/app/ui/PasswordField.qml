// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// A secret field with its show/hide button. Desktop: Kirigami's own. Phones:
// filled and rounded like UI.TextField (the side paddings stay Kirigami's:
// they make room for the button).
Kirigami.PasswordField {
    id: field

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = fieldBackground.createObject(field);
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
