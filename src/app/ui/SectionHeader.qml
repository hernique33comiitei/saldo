// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Phones: a list's section title (a date, a bank, an investment type), small
// and bold above its rows instead of Kirigami's ListSectionHeader with a line.
QQC2.Label {
    required property string section

    width: ListView.view ? ListView.view.width : implicitWidth
    leftPadding: Kirigami.Units.gridUnit
    rightPadding: Kirigami.Units.gridUnit
    topPadding: Kirigami.Units.gridUnit
    bottomPadding: Kirigami.Units.smallSpacing
    text: section
    elide: Text.ElideRight
    font.weight: Font.Bold
    font.pointSize: Kirigami.Theme.defaultFont.pointSize * Tokens.fontSection
    opacity: 0.65
    Accessible.role: Accessible.Heading
}
