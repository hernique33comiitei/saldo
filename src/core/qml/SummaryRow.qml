// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// "Icon  Label ............ R$ 1.234,56"
RowLayout {
    id: row

    property string iconName
    property string label
    property real value: 0
    property bool warnNegative: false
    property bool emphasized: false

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        visible: row.iconName.length > 0
        source: row.iconName
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium
    }
    QQC2.Label {
        Layout.fillWidth: true
        text: row.label
        elide: Text.ElideRight
        font.weight: row.emphasized ? Font.DemiBold : Font.Normal
    }
    MoneyLabel {
        value: row.value
        warnNegative: row.warnNegative
        font.weight: row.emphasized ? Font.DemiBold : Font.Normal
    }
}
