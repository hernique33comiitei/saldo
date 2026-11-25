// SPDX-License-Identifier: MIT
pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami

// Where the design system adapts: phones (Android) get its own look, the
// desktop the KDE controls untouched. The one place that decides.
QtObject {
    readonly property bool isPhone: Kirigami.Settings.isMobile
}
