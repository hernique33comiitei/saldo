// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A money amount. Honors the privacy mode (values hidden).
QQC2.Label {
    id: label

    property real value: 0
    property string currency: "BRL"
    // Prefix positive values with "+".
    property bool signed: false
    // Positive values in the positive color.
    property bool colored: false
    // Negative values in the negative color (balances).
    property bool warnNegative: false
    property bool compactFormat: false
    property bool masked: Config.privacyMode

    text: {
        if (masked) {
            return Money.masked;
        }
        if (compactFormat) {
            return Money.compact(value, currency);
        }
        return signed ? Money.formatSigned(value, currency) : Money.format(value, currency);
    }
    color: {
        if (colored && value > 0.005) {
            return Kirigami.Theme.positiveTextColor;
        }
        if (warnNegative && value < -0.005) {
            return Kirigami.Theme.negativeTextColor;
        }
        return Kirigami.Theme.textColor;
    }
    font.features: { "tnum": 1 }
    Accessible.name: masked ? i18nd("saldo", "Hidden amount") : text
}
