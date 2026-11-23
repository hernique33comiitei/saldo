// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Numbered instructions ("1. …", "2. …") with wrapped, lightly formatted text.
ColumnLayout {
    id: instructions

    // List of strings; <b>/<i> allowed.
    property var steps: []

    spacing: Kirigami.Units.smallSpacing

    Repeater {
        model: instructions.steps
        delegate: RowLayout {
            required property int index
            required property string modelData

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.alignment: Qt.AlignTop
                Layout.minimumWidth: Kirigami.Units.gridUnit
                text: i18nc("number of a step in a list", "%1.", parent.index + 1)
                font.weight: Font.DemiBold
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: parent.modelData
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
            }
        }
    }
}
