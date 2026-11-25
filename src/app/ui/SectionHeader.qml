// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A list's section title (a date, a bank, an investment type), used as a
// ListView's section.delegate. Desktop: Kirigami's ListSectionHeader (text and
// a line). Phones: small and bold above its rows, no line.
Kirigami.ListSectionHeader {
    id: header

    required property string section

    width: ListView.view ? ListView.view.width : implicitWidth
    text: section

    Component.onCompleted: {
        if (Platform.isPhone) {
            contentItem = phoneLabel.createObject(header);
            leftPadding = Kirigami.Units.gridUnit;
            rightPadding = Kirigami.Units.gridUnit;
            topPadding = Kirigami.Units.gridUnit;
            bottomPadding = Kirigami.Units.smallSpacing;
        }
    }
    Component {
        id: phoneLabel
        QQC2.Label {
            text: header.text
            elide: Text.ElideRight
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * Tokens.fontSection
            opacity: 0.65
            Accessible.role: Accessible.Heading
        }
    }
}
