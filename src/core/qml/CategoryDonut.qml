// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

// Expenses by category: ring chart + legend. `model` is a CategorySpendModel.
GridLayout {
    id: root

    property var model
    // Narrower than this, the legend goes below the ring.
    readonly property real minimumHorizontalWidth: Kirigami.Units.gridUnit * 22
    property bool vertical: width < minimumHorizontalWidth
    property real chartSize: Kirigami.Units.gridUnit * 7

    columns: vertical ? 1 : 2
    columnSpacing: Kirigami.Units.largeSpacing * 2
    rowSpacing: Kirigami.Units.largeSpacing

    Charts.ColorGradientSource {
        id: colors
        baseColor: Kirigami.Theme.highlightColor
        itemCount: Math.max(1, root.model ? root.model.count : 1)
    }

    Item {
        Layout.preferredWidth: root.chartSize
        Layout.preferredHeight: root.chartSize
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

        Charts.PieChart {
            anchors.fill: parent
            valueSources: Charts.ModelSource {
                model: root.model
                roleName: "amount"
            }
            colorSource: colors
            indexingMode: Charts.Chart.IndexAllValues
            filled: false
            thickness: Math.max(Kirigami.Units.smallSpacing * 2, width / 7)
            spacing: 0.01
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            QQC2.Label {
                Layout.alignment: Qt.AlignHCenter
                text: i18ndc("saldo", "total expenses, inside a chart", "Spent")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
            MoneyLabel {
                Layout.alignment: Qt.AlignHCenter
                value: root.model ? root.model.total : 0
                compactFormat: true
                font.weight: Font.DemiBold
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: root.model
            delegate: RowLayout {
                id: legendRow
                required property int index
                required property string name
                required property real amount
                required property real ratio

                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    implicitWidth: Kirigami.Units.smallSpacing * 2
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: colors.colors[legendRow.index] ?? Kirigami.Theme.highlightColor
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: legendRow.name
                    elide: Text.ElideRight
                }
                QQC2.Label {
                    text: Money.percent(legendRow.ratio)
                    opacity: 0.7
                    font.features: { "tnum": 1 }
                }
                MoneyLabel {
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                    horizontalAlignment: Text.AlignRight
                    value: legendRow.amount
                }
            }
        }
    }
}
