// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI
import org.saldo.core

// Diagnostics: the account JSON exactly as Pluggy returned it, to check
// units and sign conventions against the bank app.
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

    title: i18n("Raw Data")

    header: Kirigami.InlineMessage {
        position: Kirigami.InlineMessage.Header
        type: Kirigami.MessageType.Information
        visible: true
        text: i18n("Compare \"balance\" and \"creditLimit\" with your bank app. Saldo assumes amounts in reais; if they look 100 times larger, Pluggy is sending cents. Never share this data: it contains account details.")
    }

    ListView {
        id: list

        model: AccountsModel {}
        spacing: Kirigami.Units.largeSpacing

        delegate: ColumnLayout {
            id: delegate
            required property var model

            width: ListView.view.width
            spacing: Kirigami.Units.smallSpacing

            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                text: i18nc("account name (account type)", "%1 (%2)", delegate.model.name, delegate.model.subtypeLabel || delegate.model.type)
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: !json.visible
                text: Config.privacyMode ? i18n("Values are hidden. Turn off “Hide values” to see the raw data.")
                                         : i18n("No raw data stored for this account. Refresh to download it again.")
                wrapMode: Text.Wrap
                opacity: 0.7
            }

            QQC2.TextArea {
                id: json
                Layout.fillWidth: true
                visible: !Config.privacyMode && (delegate.model.raw ?? "").length > 0
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                readOnly: true
                wrapMode: TextEdit.WrapAnywhere
                font: Kirigami.Theme.fixedWidthFont
                text: {
                    try {
                        return JSON.stringify(JSON.parse(delegate.model.raw), null, 2);
                    } catch (e) {
                        return delegate.model.raw;
                    }
                }
            }

            QQC2.Button {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                visible: json.visible
                text: i18n("Copy")
                icon.name: "edit-copy"
                onClicked: {
                    json.selectAll();
                    json.copy();
                    json.deselect();
                }
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            visible: list.count === 0
            icon.name: "documentinfo"
            text: i18n("Nothing cached yet")
        }
    }
}
