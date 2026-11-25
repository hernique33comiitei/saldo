// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

// Phones: one credit card row (CardContent's counterpart): round icon, bold
// name and the limit beside it, then how much of it is used as a thick bar.
// Bills are on the card's detail page.
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

    spacing: Kirigami.Units.largeSpacing
    opacity: included ? 1 : 0.6

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        IconBadge {
            source: "view-financial-account-credit-card"
            tint: Kirigami.Theme.neutralTextColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QQC2.Label {
                Layout.fillWidth: true
                text: card.name
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: [card.cardLabel, card.numberLabel, card.institution].filter(part => part && part.length > 0).join(" · ")
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
        // The card's limit, like an account's balance.
        MoneyLabel {
            visible: card.limit > 0
            value: card.limit
            font.weight: Font.DemiBold
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: card.limit > 0
        spacing: Kirigami.Units.smallSpacing

        LimitBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.smallSpacing * 2.5
            ratio: card.ratio
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("%1 used (%2)", card.amount(card.used), Money.percent(card.ratio))
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                opacity: 0.8
            }
            QQC2.Label {
                text: i18n("%1 available", card.amount(card.available))
                font: Kirigami.Theme.smallFont
                opacity: 0.8
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: card.sharedLimit || !card.included
        text: !card.included ? i18n("Not counted in the overall limit")
                             : i18n("Shares the limit of another card; counted once")
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
}
