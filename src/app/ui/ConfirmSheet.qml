// SPDX-License-Identifier: MIT
import QtQuick
import org.kde.kirigami as Kirigami

// A question with buttons (confirm a removal, a reset). Desktop: Kirigami's
// PromptDialog, centered. Phones: a bottom sheet (SheetStyle).
Kirigami.PromptDialog {
    id: dialog

    readonly property SheetStyle sheetStyle: SheetStyle {
        sheet: dialog
    }

    Component.onCompleted: {
        sheetStyle.apply();
        if (Platform.isPhone) {
            // In line with the title (SheetStyle), more room than the dialog's.
            contentLeftPadding = Kirigami.Units.gridUnit;
            contentRightPadding = Kirigami.Units.gridUnit;
            // Its title is in the content when there is no header: below the handle.
            if (!header || !header.visible) {
                contentTopPadding = Kirigami.Units.gridUnit * 1.5;
            }
        }
    }
}
