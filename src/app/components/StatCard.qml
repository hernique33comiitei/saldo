// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core
import org.saldo.ui as UI

// A headline number: icon + label, big amount, optional caption. A card with
// no title (UI.Card).
UI.Card {
    id: card

    property string label
    property string iconName
    property real value: 0
    property string caption
    property bool warnNegative: false

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: card.iconName
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: card.label
                elide: Text.ElideRight
                opacity: 0.8
            }
        }
        MoneyLabel {
            Layout.fillWidth: true
            value: card.value
            warnNegative: card.warnNegative
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: card.caption.length > 0
            text: card.caption
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.Wrap
        }
    }
}
