// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.saldo.core

KCM.SimpleKCM {
    id: page

    property string cfg_compactDisplay
    property string cfg_compactDisplayDefault
    property bool cfg_showInvestments
    property bool cfg_showInvestmentsDefault

    Kirigami.FormLayout {
        QQC2.ButtonGroup {
            id: displayGroup
        }

        QQC2.RadioButton {
            Kirigami.FormData.label: i18nd("saldo", "Panel icon shows:")
            text: i18nd("saldo", "Only the icon")
            checked: page.cfg_compactDisplay !== "balance"
            QQC2.ButtonGroup.group: displayGroup
            onToggled: if (checked) page.cfg_compactDisplay = "icon"
        }
        QQC2.RadioButton {
            text: i18nd("saldo", "Money in accounts (not in the system tray)")
            checked: page.cfg_compactDisplay === "balance"
            QQC2.ButtonGroup.group: displayGroup
            onToggled: if (checked) page.cfg_compactDisplay = "balance"
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nd("saldo", "Summary:")
            text: i18nd("saldo", "Show investments")
            checked: page.cfg_showInvestments
            onToggled: page.cfg_showInvestments = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            text: i18nd("saldo", "Credentials, connections and sync options are in the Saldo app. Middle-click the panel icon to hide or show values.")
            wrapMode: Text.Wrap
            opacity: 0.8
        }
        QQC2.Button {
            visible: Launcher.canOpenApp
            text: i18nd("saldo", "Open Saldo Settings")
            icon.name: "configure"
            onClicked: Launcher.openApp("settings")
        }
    }
}
