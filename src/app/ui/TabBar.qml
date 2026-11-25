// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// Phones: the sections as tabs at the bottom, with a pill behind the current
// tab's icon as current Android apps do (Kirigami.NavigationTabBar draws a
// framed button instead). Pads itself by the safe areas (the gesture bar) and
// centers its tabs on wide screens like NavigationTabBar.
QQC2.ToolBar {
    id: bar

    property list<T.Action> actions
    property real maximumContentWidth: Tokens.tabBarMaxWidth

    position: QQC2.ToolBar.Footer
    // The pages' colors on phones (they use View there).
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false
    topPadding: Kirigami.Units.smallSpacing * 2
    bottomPadding: Kirigami.Units.smallSpacing * 2 + (parent ? parent.SafeArea.margins.bottom : 0)
    leftPadding: Math.floor(Math.max(0, width - maximumContentWidth) / 2) + (parent ? parent.SafeArea.margins.left : 0)
    rightPadding: Math.floor(Math.max(0, width - maximumContentWidth) / 2) + (parent ? parent.SafeArea.margins.right : 0)

    background: Rectangle {
        color: Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintBar)
    }

    contentItem: RowLayout {
        spacing: 0

        Repeater {
            model: bar.actions
            delegate: T.AbstractButton {
                id: tab
                required property T.Action modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: tabColumn.implicitHeight
                visible: modelData.visible ?? true
                enabled: modelData.enabled
                checked: modelData.checked
                text: modelData.text
                onClicked: modelData.trigger()
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.text

                contentItem: Item {
                    ColumnLayout {
                        id: tabColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: Tokens.tabPillWidth
                            implicitHeight: Tokens.tabPillHeight
                            radius: height / 2
                            color: tab.checked ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, Tokens.tintActive)
                                 : tab.down ? Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintPressed)
                                 : "transparent"

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.smallMedium
                                height: width
                                source: tab.modelData.icon.name
                                isMask: true
                                color: tab.checked ? Kirigami.Theme.textColor
                                                   : Tokens.tint(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, Tokens.tintIconIdle)
                            }
                        }
                        QQC2.Label {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: tab.width
                            text: tab.text
                            elide: Text.ElideRight
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * Tokens.fontCaption
                            font.weight: tab.checked ? Font.Bold : Font.Normal
                            opacity: tab.checked ? 1 : 0.8
                        }
                    }
                }
            }
        }
    }
}
