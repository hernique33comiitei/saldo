// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Content of one transaction row (used inside the app and widget delegates).
RowLayout {
    id: content

    property string description
    property string categoryLabel
    property string categoryIcon: "tag-symbolic"
    property string accountName
    property string installment
    property real amount: 0
    property string currency: "BRL"
    property bool pending: false
    // Movement between the user's own accounts: shown, but not counted.
    property bool internal: false
    property bool showAccount: true

    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        source: content.internal ? "exchange-positions" : content.categoryIcon
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium
        Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        QQC2.Label {
            Layout.fillWidth: true
            text: content.description
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        QQC2.Label {
            Layout.fillWidth: true
            text: [
                content.internal ? i18nd("saldo", "Between your accounts") : content.categoryLabel,
                content.showAccount ? content.accountName : "",
                content.installment.length > 0 ? i18nd("saldo", "installment %1", content.installment) : "",
                content.pending ? i18nd("saldo", "pending") : ""
            ].filter(part => part.length > 0).join(" · ")
            elide: Text.ElideRight
            maximumLineCount: 1
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }

    MoneyLabel {
        Layout.alignment: Qt.AlignVCenter
        value: content.amount
        currency: content.currency
        signed: true
        colored: !content.internal
        opacity: content.internal ? 0.55 : content.pending ? 0.7 : 1
    }
}
