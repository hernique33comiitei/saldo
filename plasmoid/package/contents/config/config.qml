// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nd("saldo", "General")
        icon: "configure"
        source: "ConfigGeneral.qml"
    }
}
