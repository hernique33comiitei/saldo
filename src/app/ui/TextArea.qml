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
            // Each side: Breeze sets them one by one, which win over `padding`.
            leftPadding = Kirigami.Units.largeSpacing * 1.5;
            rightPadding = Kirigami.Units.largeSpacing * 1.5;
            topPadding = Kirigami.Units.largeSpacing;
            bottomPadding = Kirigami.Units.largeSpacing;
        }
    }
    Component {
        id: areaBackground
        FieldBackground {
            control: area
        }
    }
}
