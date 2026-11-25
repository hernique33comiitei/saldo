// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A number with minus/plus buttons (a SpinBox). Desktop: the style's own.
// Phones: a filled, rounded box with round − and + buttons at its ends.
QQC2.SpinBox {
    id: spin

    // Phones: where the − (left) and + (right) buttons sit.
    function stepX(plus: bool): real {
        return plus ? spin.width - Tokens.touchTarget - Kirigami.Units.smallSpacing : Kirigami.Units.smallSpacing;
    }

    Component.onCompleted: {
        if (Platform.isPhone) {
            background = phoneBackground.createObject(spin);
            // The style's indicators stay (the SpinBox hit-tests them), see-
            // through and placed where the round buttons are drawn: replacing
            // them left the old ones computing on a null parent.
            for (const plus of [false, true]) {
                const indicator = plus ? up.indicator : down.indicator;
                indicator.opacity = 0;
                indicator.width = Tokens.touchTarget;
                indicator.height = Tokens.touchTarget;
                indicator.x = Qt.binding(() => stepX(plus));
                indicator.y = Qt.binding(() => Math.round((spin.height - Tokens.touchTarget) / 2));
                stepButton.createObject(spin, { plus: plus });
            }
            // Room for the value between the − and + buttons, whatever width
            // the page asked for.
            if (!(Layout.preferredWidth >= Tokens.numberFieldWidth)) {
                Layout.preferredWidth = Tokens.numberFieldWidth;
            }
            leftPadding = Tokens.touchTarget + Kirigami.Units.smallSpacing * 2;
            rightPadding = Tokens.touchTarget + Kirigami.Units.smallSpacing * 2;
        }
    }

    Component {
        id: phoneBackground
        FieldBackground {
            control: spin
            implicitWidth: Kirigami.Units.gridUnit * 9
        }
    }
    Component {
        id: stepButton
        Rectangle {
            property bool plus
            readonly property bool pressed: plus ? spin.up.pressed : spin.down.pressed
            readonly property bool active: plus ? spin.value < spin.to : spin.value > spin.from

            x: spin.stepX(plus)
            y: Math.round((spin.height - height) / 2)
            implicitWidth: Tokens.touchTarget
            implicitHeight: Tokens.touchTarget
            radius: width / 2
            opacity: active && spin.enabled ? 1 : 0.4
            color: Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, pressed ? Tokens.tintSelected : Tokens.tintChip)

            // Drawn as text: Breeze's list-remove is a cross, not a minus.
            QQC2.Label {
                anchors.centerIn: parent
                text: parent.plus ? "+" : "\u2212"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * Tokens.fontMoneyMedium
                font.weight: Font.DemiBold
            }
        }
    }
}
