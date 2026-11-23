// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.quickcharts as Charts

// Ring showing used vs. total credit limit, with the percentage in the middle.
Item {
    id: donut

    property real used: 0
    property real limit: 0
    readonly property real ratio: limit > 0 ? used / limit : 0
    readonly property color usageColor: ratio >= 0.8 ? Kirigami.Theme.negativeTextColor
                                      : ratio >= 0.5 ? Kirigami.Theme.neutralTextColor
                                      : Kirigami.Theme.positiveTextColor

    implicitWidth: Kirigami.Units.gridUnit * 7
    implicitHeight: implicitWidth

    Accessible.role: Accessible.ProgressBar
    Accessible.name: i18nd("saldo", "%1% of the credit limit used", Math.round(ratio * 100))

    Charts.PieChart {
        id: pie
        anchors.fill: parent
        range.from: 0
        range.to: Math.max(donut.limit, 0.01)
        range.automatic: false
        valueSources: Charts.SingleValueSource { value: Math.min(donut.used, donut.limit) }
        colorSource: Charts.SingleValueSource { value: donut.usageColor }
        backgroundColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
        thickness: Math.max(Kirigami.Units.smallSpacing * 2, width / 9)
        filled: false
        smoothEnds: true
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: Money.percent(donut.ratio)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * (donut.width > Kirigami.Units.gridUnit * 5 ? 1.6 : 1.1)
            font.weight: Font.DemiBold
        }
        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            visible: donut.width > Kirigami.Units.gridUnit * 4
            text: i18ndc("saldo", "credit limit used, below a percentage", "used")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
