// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

import "chartscale.js" as ChartScale

// Bank balance over time. `model` is a BalanceHistoryModel. Value axis on the
// left, first and last day below.
Item {
    id: root

    property var model
    // History comes from daily snapshots: it needs a couple of days to draw.
    readonly property bool hasHistory: model ? model.count >= 2 : false
    // Fewer value axis lines on short charts.
    readonly property bool tall: height >= Kirigami.Units.gridUnit * 7
    readonly property var axis: ChartScale.around(model ? model.minValue : 0, model ? model.maxValue : 0, tall ? 3 : 2, tall ? 5 : 3)

    function axisText(value) {
        return Config.privacyMode ? Money.masked : Money.axisLabel(value, axis.step);
    }

    implicitHeight: Kirigami.Units.gridUnit * 8

    QQC2.Label {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: !root.hasHistory
        text: i18nd("saldo", "Saldo records your balance once a day; this chart fills in over the next days.")
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.7
    }

    TextMetrics {
        id: widestValue
        font: Kirigami.Theme.smallFont
        text: {
            const top = root.axisText(root.axis.to);
            const bottom = root.axisText(root.axis.from);
            return top.length >= bottom.length ? top : bottom;
        }
    }

    // The first and last days sit this far from the edges, so each date is
    // centered under its point without touching the corner (like the months
    // under the bars). The line itself still runs edge to edge: it continues
    // flat from the edge to the first day and from the last day to the edge.
    // Whole pixels, so the continuations meet the chart without a seam.
    readonly property real inset: Math.round(Math.max(firstDay.implicitWidth, lastDay.implicitWidth) / 2 + Kirigami.Units.largeSpacing)

    // Where LineChart draws a value. The continuation of the line is
    // antialiased so it lands on the same sub-pixel height as the chart's line;
    // its fill is not (an antialiased edge would overlap the chart's fill and
    // draw a darker column at the junction).
    function valueY(value) {
        return plot.height * (1 - (value - axis.from) / Math.max(1e-9, axis.to - axis.from));
    }

    // Area right of the value labels: grid lines span all of it.
    Item {
        id: plot
        anchors {
            left: parent.left
            leftMargin: Math.ceil(widestValue.width) + Kirigami.Units.smallSpacing
            right: parent.right
            top: parent.top
            topMargin: widestValue.height / 2
            bottom: days.top
            bottomMargin: Kirigami.Units.smallSpacing
        }
    }

    // Grid lines and the value of each one.
    Repeater {
        model: root.hasHistory ? root.axis.intervals + 1 : 0
        delegate: Item {
            id: tick
            required property int index
            readonly property real lineY: plot.y + plot.height * (1 - index / root.axis.intervals)

            Rectangle {
                x: plot.x
                y: tick.lineY
                width: plot.width
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

    // Flat continuations of the line to the edges (with the same fill).
    Repeater {
        model: root.hasHistory ? [
            { x: 0, value: root.model.firstValue },
            { x: plot.width - root.inset, value: root.model.lastValue }
        ] : []
        delegate: Item {
            id: edge
            required property var modelData
            x: plot.x + modelData.x
            y: plot.y
            width: root.inset
            height: plot.height

            Rectangle {
                y: root.valueY(edge.modelData.value)
                width: parent.width
                height: parent.height - y
                color: Kirigami.Theme.highlightColor
                opacity: line.fillOpacity
            }
            Rectangle {
                y: root.valueY(edge.modelData.value) - height / 2
                width: parent.width
                height: line.lineWidth
                antialiasing: true
                color: Kirigami.Theme.highlightColor
            }
        }
    }

    Charts.LineChart {
        id: line
        visible: root.hasHistory
        anchors {
            fill: plot
            leftMargin: root.inset
            rightMargin: root.inset
        }
        valueSources: Charts.ModelSource {
            model: root.model
            roleName: "total"
        }
        colorSource: Charts.SingleValueSource { value: Kirigami.Theme.highlightColor }
        fillOpacity: 0.15
        lineWidth: 2
        interpolate: true
        yRange.from: root.axis.from
        yRange.to: root.axis.to
        yRange.automatic: false
    }

    // First and last day, each centered under its point.
    Item {
        id: days
        visible: root.hasHistory
        anchors {
            left: plot.left
            right: plot.right
            bottom: parent.bottom
        }
        height: firstDay.implicitHeight

        QQC2.Label {
            id: firstDay
            x: root.inset - width / 2
            text: root.model ? Money.dayMonth(root.model.firstDay) : ""
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.Label {
            id: lastDay
            x: parent.width - root.inset - width / 2
            text: root.model ? Money.dayMonth(root.model.lastDay) : ""
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
