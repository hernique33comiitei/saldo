// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

// Phones: the overview's headline card, balance in accounts plus the month's
// income and expenses on the app icon's green. The only place with colors of
// its own (CLAUDE.md): greens dark enough for white text at 4.5:1 or more
// (#17845a 4.7:1, the darker band 5.9:1); the icon's own #1b9e6b gave 3.4:1.
Rectangle {
    id: hero

    property real balance: 0
    property string caption
    property real income: 0
    // Money going out, negative (or zero).
    property real expense: 0

    readonly property color textColor: "white"

    implicitHeight: column.implicitHeight + Kirigami.Units.gridUnit * 2.5
    radius: Kirigami.Units.gridUnit * 1.25
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#136b49" }
        GradientStop { position: 1; color: "#17845a" }
    }

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Kirigami.Units.gridUnit * 1.25
            rightMargin: Kirigami.Units.gridUnit * 1.25
        }
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("In accounts")
            color: hero.textColor
            elide: Text.ElideRight
        }
        MoneyLabel {
            Layout.fillWidth: true
            value: hero.balance
            color: hero.textColor
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.4
            font.weight: Font.Bold
            // Large balances shrink instead of running past the card.
            fontSizeMode: Text.HorizontalFit
            minimumPointSize: Kirigami.Theme.defaultFont.pointSize
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: hero.caption.length > 0
            text: hero.caption
            color: hero.textColor
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
            elide: Text.ElideRight
        }

        // The month's income and expenses on a darker band.
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            implicitHeight: flows.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.gridUnit * 0.75
            color: Qt.rgba(0, 0, 0, 0.14)

            RowLayout {
                id: flows
                anchors {
                    fill: parent
                    margins: Kirigami.Units.largeSpacing
                }
                spacing: Kirigami.Units.largeSpacing

                Repeater {
                    model: [
                        { name: i18n("Income in the month"), value: hero.income, icon: "go-down-symbolic" },
                        { name: i18n("Expenses in the month"), value: Math.abs(hero.expense), icon: "go-up-symbolic" }
                    ]
                    delegate: RowLayout {
                        id: flow
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            implicitWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 3
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.18)
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                source: flow.modelData.icon
                                isMask: true
                                color: hero.textColor
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: flow.modelData.name
                                color: hero.textColor
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                                elide: Text.ElideRight
                            }
                            MoneyLabel {
                                Layout.fillWidth: true
                                value: flow.modelData.value
                                color: hero.textColor
                                font.weight: Font.DemiBold
                                fontSizeMode: Text.HorizontalFit
                                minimumPointSize: Kirigami.Theme.defaultFont.pointSize * 0.7
                            }
                        }
                    }
                }
            }
        }
    }
}
