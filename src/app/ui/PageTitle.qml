// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A page's title on phones in the header, large and bold as current Android
// apps show it. Pages use it as their titleDelegate on phones only; sized like
// Kirigami's own DefaultPageTitleDelegate.
Item {
    property alias text: heading.text

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.maximumWidth: implicitWidth
    implicitWidth: Math.ceil(heading.implicitWidth)
    implicitHeight: Math.ceil(heading.implicitHeight)

    Kirigami.Heading {
        id: heading
        anchors.fill: parent
        level: 1
        font.weight: Font.Bold
        maximumLineCount: 1
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
    }
}
