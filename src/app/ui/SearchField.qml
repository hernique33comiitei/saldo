// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// A search field. Desktop: Kirigami's own. Phones: a filled pill (the side
// paddings stay Kirigami's: they make room for its icons).
Kirigami.SearchField {
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
            pill: true
        }
    }
}
