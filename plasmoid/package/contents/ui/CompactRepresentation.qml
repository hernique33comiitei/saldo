// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.saldo.core

// Panel / tray icon. Left click opens the popup, middle click toggles privacy.
MouseArea {
    id: compact

    readonly property bool inTray: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentDrawsPlasmoidHeading) !== 0
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool showBalance: root.compactDisplay === "balance" && !inTray && !vertical && FinanceSummary.hasData
    property bool wasExpanded: false

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true

    Layout.minimumWidth: vertical ? -1 : row.implicitWidth
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: vertical ? width : -1

    onPressed: root.expanded !== undefined && (wasExpanded = root.expanded)
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            Config.privacyMode = !Config.privacyMode;
            return;
        }
        root.expanded = !wasExpanded;
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            id: icon
            Layout.fillHeight: true
            Layout.preferredWidth: compact.vertical ? compact.width : compact.height
            source: Plasmoid.icon
            active: compact.containsMouse
            opacity: Credentials.configured && !FinanceSummary.hasData ? 0.6 : 1

            Rectangle {
                // Something needs the user (sync error, expiring authorization).
                visible: root.needsAttention
                anchors {
                    right: parent.right
                    top: parent.top
                }
                width: Math.round(parent.width * 0.3)
                height: width
                radius: width / 2
                color: Kirigami.Theme.negativeTextColor
                border.color: Kirigami.Theme.backgroundColor
                border.width: 1
            }
        }

        PlasmaComponents3.Label {
            visible: compact.showBalance
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            text: Config.privacyMode ? Money.masked : Money.compact(FinanceSummary.totalCash)
            font.features: { "tnum": 1 }
        }
    }
}
