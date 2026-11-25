// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// A dialog. Desktop: Kirigami's, centered. Phones: a bottom sheet
// (SheetStyle).
Kirigami.Dialog {
    id: dialog

    readonly property SheetStyle sheetStyle: SheetStyle {
        sheet: dialog
    }

    Component.onCompleted: sheetStyle.apply()
}
