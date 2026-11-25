// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A one-line text field. Desktop: the style's own. Phones: filled and
// rounded, outlined while focused (FieldBackground).
QQC2.TextField {
    id: field

    // Phones: outline the field in the negative color (a wrong value).
    property bool error: false

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = fieldBackground.createObject(field);
            leftPadding = Kirigami.Units.largeSpacing * 1.5;
            rightPadding = Kirigami.Units.largeSpacing * 1.5;
            topPadding = Kirigami.Units.largeSpacing;
            bottomPadding = Kirigami.Units.largeSpacing;
        }
    }
    Component {
        id: fieldBackground
        FieldBackground {
            control: field
            error: field.error
        }
    }
}
