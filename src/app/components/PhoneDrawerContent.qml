// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

// Phones: the drawer's content (its sections are tabs there): the app, when
// Pluggy last updated the banks, what is connected, then the pages that are
// not tabs.
ColumnLayout {
    id: content

    property string currentPage
    property bool setupComplete: false

    signal pageRequested(string name)

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.gridUnit
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Image {
            source: "qrc:/icons/saldo.svg"
            sourceSize.width: Kirigami.Units.iconSizes.large
            sourceSize.height: Kirigami.Units.iconSizes.large
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Kirigami.Heading {
                Layout.fillWidth: true
                text: i18n("Saldo")
                level: 1
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: FinanceSummary.dataUpdatedAt.getTime && !isNaN(FinanceSummary.dataUpdatedAt.getTime())
                      ? i18n("Pluggy updated your banks %1", Money.relativeTime(FinanceSummary.dataUpdatedAt))
                      : ""
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                opacity: 0.75
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        visible: FinanceSummary.hasData
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: [
                i18np("%1 account", "%1 accounts", FinanceSummary.accountCount),
                i18np("%1 card", "%1 cards", FinanceSummary.cardCount),
                i18np("%1 investment", "%1 investments", FinanceSummary.investmentCount)
            ]
            delegate: Rectangle {
                id: chip
                required property string modelData
                implicitWidth: chipText.implicitWidth + Kirigami.Units.largeSpacing * 2
                implicitHeight: chipText.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: height / 2
                color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
                QQC2.Label {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                }
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.gridUnit
        Layout.bottomMargin: Kirigami.Units.largeSpacing
        opacity: 0.5
    }

    DrawerItem {
        visible: !content.setupComplete
        text: i18n("Connect Meu Pluggy")
        iconName: "wallet-open"
        active: content.currentPage === "setup"
        onClicked: content.pageRequested("setup")
    }
    DrawerItem {
        text: i18n("Settings")
        iconName: "configure"
        active: content.currentPage === "settings"
        onClicked: content.pageRequested("settings")
    }
    DrawerItem {
        text: i18n("About Saldo")
        iconName: "help-about"
        active: content.currentPage === "about"
        onClicked: content.pageRequested("about")
    }
}
