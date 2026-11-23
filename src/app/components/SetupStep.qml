// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// One step of the setup guide: numbered badge on a vertical rail, a title,
// a one-line summary when collapsed and its content when it is the open step.
RowLayout {
    id: step

    enum Status {
        Upcoming,
        Current,
        Done
    }

    property int number: 1
    property string title
    // Shown under the title when the step is not open (e.g. what was saved).
    property string summary
    property int status: SetupStep.Upcoming
    // The open step shows its content; the others only their header.
    property bool expanded: false
    property bool last: false
    default property alias content: body.data

    signal headerClicked()

    spacing: Kirigami.Units.largeSpacing

    ColumnLayout {
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.gridUnit * 1.6
            implicitHeight: implicitWidth
            radius: width / 2
            color: step.status === SetupStep.Done ? Kirigami.Theme.positiveTextColor
                 : step.expanded ? Kirigami.Theme.highlightColor
                 : "transparent"
            border.width: step.status === SetupStep.Done || step.expanded ? 0 : 1
            border.color: Kirigami.Theme.disabledTextColor

            Kirigami.Icon {
                anchors.centerIn: parent
                visible: step.status === SetupStep.Done
                source: "dialog-ok-apply"
                color: Kirigami.Theme.backgroundColor
                isMask: true
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.Label {
                anchors.centerIn: parent
                visible: step.status !== SetupStep.Done
                text: step.number
                font.weight: Font.DemiBold
                color: step.expanded ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            visible: !step.last
            implicitWidth: 2
            color: step.status === SetupStep.Done ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
            opacity: 0.5
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: step.last ? 0 : Kirigami.Units.gridUnit
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing / 2
            level: 3
            text: step.title
            wrapMode: Text.Wrap
            opacity: step.status === SetupStep.Upcoming && !step.expanded ? 0.6 : 1

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: step.headerClicked()
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: !step.expanded && step.status === SetupStep.Done && step.summary.length > 0
            text: step.summary
            wrapMode: Text.Wrap
            opacity: 0.7
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: step.expanded
            spacing: Kirigami.Units.largeSpacing
        }
    }
}
