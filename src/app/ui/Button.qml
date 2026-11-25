// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A push button. Desktop: the style's own, whatever the variant. Phones: a
// pill, filled with the highlight color (Primary), tinted (Secondary) or bare
// (Flat).
QQC2.Button {
    id: button

    enum Variant {
        Secondary,
        Primary,
        Flat
    }

    property int variant: Button.Secondary

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = pillBackground.createObject(button, { control: button, variant: Qt.binding(() => button.variant) });
            contentItem = pillContent.createObject(button, { control: button, variant: Qt.binding(() => button.variant) });
            leftPadding = Kirigami.Units.gridUnit;
            rightPadding = Kirigami.Units.gridUnit;
            topPadding = Kirigami.Units.smallSpacing;
            bottomPadding = Kirigami.Units.smallSpacing;
        }
    }

    Component {
        id: pillBackground
        PillBackground {}
    }
    Component {
        id: pillContent
        PillContent {}
    }
}
