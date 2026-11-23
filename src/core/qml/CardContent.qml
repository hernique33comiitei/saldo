// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Content of one credit card row: name and limit meter. Bills are on the
// card's detail page.
ColumnLayout {
    id: card

    property string name
    property string numberLabel
    property string cardLabel
    property string institution
    property real limit: 0
    property real used: 0
    property real available: 0
    property real ratio: 0
    property bool sharedLimit: false
    property bool included: true

    function amount(value) {
        return Config.privacyMode ? Money.masked : Money.format(value);
    }

    spacing: Kirigami.Units.smallSpacing
    opacity: included ? 1 : 0.6

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: "view-financial-account-credit-card"
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QQC2.Label {
                Layout.fillWidth: true
                text: card.name
                elide: Text.ElideRight
                font.weight: Font.DemiBold
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: [card.cardLabel, card.numberLabel, card.institution].filter(part => part && part.length > 0).join(" · ")
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
    }

    LimitBar {
        Layout.fillWidth: true
        visible: card.limit > 0
        ratio: card.ratio
    }

    RowLayout {
        Layout.fillWidth: true
        visible: card.limit > 0
        QQC2.Label {
            Layout.fillWidth: true
            text: i18nd("saldo", "%1 used of %2", card.amount(card.used), card.amount(card.limit))
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            opacity: 0.8
        }
        QQC2.Label {
            text: i18nd("saldo", "%1 available", card.amount(card.available))
            font: Kirigami.Theme.smallFont
            opacity: 0.8
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: card.sharedLimit || !card.included
        text: !card.included ? i18nd("saldo", "Not counted in the overall limit")
                             : i18nd("saldo", "Shares the limit of another card; counted once")
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
