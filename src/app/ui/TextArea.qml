// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Multi-line text. Desktop: the style's own. Phones: filled and rounded like
// UI.TextField.
QQC2.TextArea {
    id: area

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = areaBackground.createObject(area);
            padding = Kirigami.Units.largeSpacing * 1.5;
        }
    }
    Component {
        id: areaBackground
        FieldBackground {
            control: area
        }
    }
}
