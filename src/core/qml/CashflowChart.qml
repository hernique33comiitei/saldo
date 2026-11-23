// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

import "chartscale.js" as ChartScale

// Monthly income vs. expenses bars. `model` is a CashflowModel. Value axis on
// the left, each month centered under its pair of bars, a month's values on
// hover.
ColumnLayout {
    id: root

    property var model
    property bool showLegend: true
    property real chartHeight: Kirigami.Units.gridUnit * 8
    // Fewer value axis lines on short charts (the widget).
    readonly property bool tall: chartHeight >= Kirigami.Units.gridUnit * 7

    // Explicit range so the axis labels match the bars. Safe because the
    // model emits summaryChanged (maxValue) before it swaps the rows.
    readonly property var axis: ChartScale.zeroBased(model ? model.maxValue : 0, tall ? 3 : 2, tall ? 5 : 3)
    readonly property int count: model ? model.count : 0

    function axisText(value) {
        return Config.privacyMode ? Money.masked : Money.axisLabel(value, axis.step);
    }
    function amount(value) {
        return Config.privacyMode ? Money.masked : Money.format(value);
    }

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        visible: root.showLegend
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: [
                { name: i18nd("saldo", "Income"), color: Kirigami.Theme.positiveTextColor },
                { name: i18nd("saldo", "Expenses"), color: Kirigami.Theme.negativeTextColor }
            ]
            delegate: RowLayout {
                required property var modelData
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    implicitWidth: Kirigami.Units.smallSpacing * 2
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: modelData.color
                }
                QQC2.Label {
                    text: modelData.name
                    font: Kirigami.Theme.smallFont
                }
            }
        }
    }

    Item {
        id: plot

        Layout.fillWidth: true
        Layout.preferredHeight: root.chartHeight

        TextMetrics {
            id: widestValue
            font: Kirigami.Theme.smallFont
            text: root.axisText(root.axis.to)
        }

        // Grid lines and the value of each one.
        Repeater {
            model: root.axis.intervals + 1
            delegate: Item {
                id: tick
                required property int index
                readonly property real lineY: bars.y + bars.height * (1 - index / root.axis.intervals)

                Rectangle {
                    x: bars.x
                    y: tick.lineY
                    width: bars.width
                    height: 1
                    color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
                }
                QQC2.Label {
                    width: widestValue.width
                    y: tick.lineY - height / 2
                    horizontalAlignment: Text.AlignRight
                    text: root.axisText(root.axis.from + tick.index * root.axis.step)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
        }

        // Hovered month.
        Rectangle {
            visible: hover.index >= 0
            x: bars.x + hover.index * hover.columnWidth
            y: bars.y
            width: hover.columnWidth
            height: bars.height
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.highlightColor
            opacity: 0.15
        }

        Charts.BarChart {
            id: bars
            anchors {
                left: parent.left
                leftMargin: widestValue.width + Kirigami.Units.smallSpacing
                right: parent.right
                top: parent.top
                topMargin: widestValue.height / 2
                bottom: months.top
                bottomMargin: Kirigami.Units.smallSpacing
            }
            valueSources: [
                Charts.ModelSource { model: root.model; roleName: "income" },
                Charts.ModelSource { model: root.model; roleName: "expense" }
            ]
            colorSource: Charts.ArraySource { array: [Kirigami.Theme.positiveTextColor, Kirigami.Theme.negativeTextColor] }
            nameSource: Charts.ArraySource { array: [i18nd("saldo", "Income"), i18nd("saldo", "Expenses")] }
            yRange.from: root.axis.from
            yRange.to: root.axis.to
            yRange.automatic: false
            spacing: Kirigami.Units.smallSpacing / 2
            radius: 2
        }

        // One label per month, centered under its bars.
        Row {
            id: months
            anchors {
                left: bars.left
                right: bars.right
                bottom: parent.bottom
            }
            Repeater {
                model: root.model
                delegate: QQC2.Label {
                    required property string label
                    width: months.width / Math.max(1, root.count)
                    horizontalAlignment: Text.AlignHCenter
                    text: label
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
        }

        MouseArea {
            id: hover

            readonly property real columnWidth: bars.width / Math.max(1, root.count)
            readonly property int index: (containsMouse || pressed) && root.count > 0
                                         ? Math.max(0, Math.min(root.count - 1, Math.floor(mouseX / columnWidth))) : -1
            readonly property var row: index >= 0 && root.model ? root.model.get(index) : null

            anchors.fill: bars
            hoverEnabled: true

            QQC2.ToolTip {
                visible: hover.row !== null
                x: Math.max(0, Math.min(hover.width - width, (hover.index + 0.5) * hover.columnWidth - width / 2))
                y: -height - Kirigami.Units.smallSpacing
                text: hover.row ? [hover.row.monthLabel,
                                   i18nd("saldo", "Income: %1", root.amount(hover.row.income)),
                                   i18nd("saldo", "Expenses: %1", root.amount(hover.row.expense))].join("\n") : ""
            }
        }
    }
}
