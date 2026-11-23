// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

// A headline number: icon + title, big amount, optional caption.
Kirigami.AbstractCard {
    id: card

    property string title
    property string iconName
    property real value: 0
    property string caption
    property bool warnNegative: false

    padding: Kirigami.Units.gridUnit

    // The column keeps its own height inside a wrapper (see SectionCard): a
    // stretched card would otherwise spread its rows apart.
    contentItem: Item {
        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            width: parent.width
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
                    text: card.title
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
}
