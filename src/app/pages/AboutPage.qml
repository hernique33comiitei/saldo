// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI

// About Saldo, from the application's KAboutData. Our own page instead of
// Kirigami.AboutPage: that one always draws an initials avatar per author and
// opens the license in a sheet glued to the top of the window.
Kirigami.ScrollablePage {
    id: page

    // Phones: a large bold title in the header (PhoneTitle), and the View
    // colors, which the header, the tabs and the drawer share there (list
    // pages took them and the others the Window ones: two greys).
    Component.onCompleted: {
        if (Kirigami.Settings.isMobile) {
            titleDelegate = phoneTitle;
            Kirigami.Theme.colorSet = Kirigami.Theme.View;
        }
    }
    Component {
        id: phoneTitle
        UI.PageTitle {
            text: page.title
        }
    }

    readonly property var aboutData: About.aboutData

    // An author, credit or translator: name, role, website and email buttons.
    component PersonRow: RowLayout {
        id: person

        // KAboutPerson: name, task, emailAddress, webAddress
        required property var modelData

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QQC2.Label {
                Layout.fillWidth: true
                text: person.modelData.name
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: person.modelData.task ?? ""
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
        QQC2.ToolButton {
            visible: (person.modelData.webAddress ?? "").length > 0
            icon.name: "globe"
            text: person.modelData.webAddress ?? ""
            display: QQC2.AbstractButton.IconOnly
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: Qt.openUrlExternally(person.modelData.webAddress)
        }
        QQC2.ToolButton {
            visible: (person.modelData.emailAddress ?? "").length > 0
            icon.name: "mail-sent"
            text: i18n("Send an email to %1", person.modelData.emailAddress ?? "")
            display: QQC2.AbstractButton.IconOnly
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: Qt.openUrlExternally("mailto:" + person.modelData.emailAddress)
        }
    }

    // A row that opens something (license text, a web page).
    component LinkRow: QQC2.ItemDelegate {
        id: link

        property string trailingIcon: "go-next-symbolic"

        Layout.fillWidth: true
        leftPadding: 0
        rightPadding: 0
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                visible: link.icon.name.length > 0
                source: link.icon.name
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: link.text
                elide: Text.ElideRight
            }
            Kirigami.Icon {
                source: link.trailingIcon
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                opacity: 0.7
            }
        }
    }

    title: i18n("About Saldo")

    ColumnLayout {
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 36
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.gridUnit

            // Name, version, description and copyright. Same content wrapper
            // as SectionCard (keeps the column at its own height).
            Kirigami.AbstractCard {
                Layout.fillWidth: true
                padding: Kirigami.Units.gridUnit

                contentItem: Item {
                    implicitWidth: headerColumn.implicitWidth
                    implicitHeight: headerColumn.implicitHeight

                    ColumnLayout {
                        id: headerColumn
                        width: parent.width
                        spacing: Kirigami.Units.largeSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.gridUnit

                            Image {
                                source: "qrc:/icons/saldo.svg"
                                sourceSize.width: Kirigami.Units.iconSizes.huge
                                sourceSize.height: Kirigami.Units.iconSizes.huge
                                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Heading {
                                    Layout.fillWidth: true
                                    text: i18nc("application name and version", "%1 %2", page.aboutData.displayName, page.aboutData.version)
                                    wrapMode: Text.Wrap
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: page.aboutData.shortDescription
                                    wrapMode: Text.Wrap
                                    opacity: 0.8
                                }
                            }
                        }

                        Kirigami.Separator {
                            Layout.fillWidth: true
                            visible: copyright.text.length > 0
                        }
                        QQC2.Label {
                            id: copyright
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: page.aboutData.copyrightStatement
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            UI.Card {
                Layout.fillWidth: true
                visible: licenses.count > 0
                title: i18n("License")

                Repeater {
                    id: licenses
                    model: page.aboutData.licenses
                    delegate: LinkRow {
                        required property var modelData
                        text: modelData.name
                        onClicked: {
                            // License texts are hard-wrapped at ~76 columns: join
                            // each line with the next so paragraphs wrap to the
                            // dialog's width, keeping empty lines and lines that
                            // start with whitespace.
                            licenseDialog.text = modelData.text.replace(/([^\r\n])\r?\n(?!\s)/g, "$1 ");
                            licenseDialog.title = modelData.name;
                            licenseDialog.open();
                        }
                    }
                }
            }

            UI.Card {
                Layout.fillWidth: true
                visible: page.aboutData.homepage.toString().length > 0 || page.aboutData.bugAddress.length > 0
                title: i18n("Links")

                LinkRow {
                    visible: page.aboutData.homepage.toString().length > 0
                    text: i18n("Homepage")
                    icon.name: "globe"
                    trailingIcon: "open-link-symbolic"
                    onClicked: Qt.openUrlExternally(page.aboutData.homepage)
                }
                LinkRow {
                    visible: page.aboutData.bugAddress.length > 0
                    text: i18n("Report a Bug")
                    icon.name: "tools-report-bug"
                    trailingIcon: "open-link-symbolic"
                    onClicked: {
                        const address = page.aboutData.bugAddress;
                        Qt.openUrlExternally(address.includes("@") && !address.includes(":") ? "mailto:" + address : address);
                    }
                }
            }

            UI.Card {
                Layout.fillWidth: true
                visible: authors.count > 0
                title: i18n("Authors")

                Repeater {
                    id: authors
                    model: page.aboutData.authors
                    delegate: PersonRow {}
                }
            }

            UI.Card {
                Layout.fillWidth: true
                visible: credits.count > 0
                title: i18n("Credits")

                Repeater {
                    id: credits
                    model: page.aboutData.credits
                    delegate: PersonRow {}
                }
            }

            UI.Card {
                Layout.fillWidth: true
                visible: translators.count > 0
                title: i18n("Translators")

                Repeater {
                    id: translators
                    model: page.aboutData.translators
                    delegate: PersonRow {}
                }
            }
        }
    }

    // Kirigami.Dialog sits centered in the window.
    Kirigami.Dialog {
        id: licenseDialog

        property alias text: licenseText.text

        // The unwrapped text would otherwise stretch it to the window's width.
        preferredWidth: Kirigami.Units.gridUnit * 32
        maximumWidth: Math.min(Kirigami.Units.gridUnit * 32, applicationWindow().width - Kirigami.Units.gridUnit * 2)
        maximumHeight: applicationWindow().height - Kirigami.Units.gridUnit * 4
        standardButtons: Kirigami.Dialog.NoButton

        Kirigami.SelectableLabel {
            id: licenseText
            leftPadding: Kirigami.Units.gridUnit
            rightPadding: Kirigami.Units.gridUnit
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.gridUnit
            wrapMode: Text.Wrap
        }
    }
}
