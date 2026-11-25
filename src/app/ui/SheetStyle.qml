// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// Phones: turns a Kirigami dialog into a bottom sheet (UI.Sheet,
// UI.ConfirmSheet): full width at the bottom, rounded on top with a handle,
// sliding in and out, closed by dragging the handle down (or tapping outside,
// or Android's back), clear of the gesture bar. Does nothing on the desktop.
QtObject {
    id: style

    property T.Popup sheet

    // At the bottom of the window, or on top of the on-screen keyboard,
    // following the sheet's height.
    function anchorBottom() {
        sheet.y = Qt.binding(() => sheet.parent ? Platform.keyboardTop(sheet.parent) - sheet.height : 0);
    }
    // Room under the sheet's last row: the gesture bar's, or a gap above
    // the on-screen keyboard while it shows (it covers the gesture bar; with
    // no gap the buttons touched it).
    function safeBottom(): real {
        const s = sheet;
        if (!s || !s.parent) {
            return 0;
        }
        if (Platform.keyboardTop(s.parent) < s.parent.height) {
            return Kirigami.Units.gridUnit;
        }
        return s.parent.SafeArea.margins.bottom;
    }

    // The enter transition leaves a fixed y: bound again once open, so the
    // sheet stays at the bottom if its content changes height. (A Connections:
    // the popup's `opened` property hides its opened() signal from .connect.)
    property Connections whenOpened: Connections {
        target: Platform.isPhone ? style.sheet : null
        function onAboutToShow() {
            style.styleButtons(style.sheet.footer);
            style.styleIconButtons(style.sheet.header);
        }
        function onOpened() {
            style.anchorBottom();
        }
    }

    // Phones: the dialog's footer buttons (Kirigami creates them from
    // standardButtons and customFooterActions) as the design system's pills,
    // text only: the accepting one Primary, Cancel/No/Close/Discard Flat, a
    // custom action Secondary. Done before each opening: some are created late.
    function styleButtons(item) {
        if (!item) {
            return;
        }
        for (const child of item.children) {
            if (child instanceof T.AbstractButton && child.visible !== undefined) {
                styleButton(child);
            } else {
                styleButtons(child);
            }
        }
    }
    function styleButton(button) {
        if (button.objectName === "saldoPill") {
            return;
        }
        button.objectName = "saldoPill";
        const dialog = sheet;
        const standard = role => dialog.standardButton ? dialog.standardButton(role) : null;
        const accept = [T.Dialog.Ok, T.Dialog.Save, T.Dialog.Yes, T.Dialog.Apply, T.Dialog.Open, T.Dialog.YesToAll]
            .some(role => standard(role) === button);
        const reject = [T.Dialog.Cancel, T.Dialog.No, T.Dialog.Close, T.Dialog.Discard, T.Dialog.Abort, T.Dialog.NoToAll]
            .some(role => standard(role) === button);
        const variant = accept ? Button.Primary : reject ? Button.Flat : Button.Secondary;
        button.display = T.AbstractButton.TextOnly;
        button.background = pillBackgroundComponent.createObject(button, { control: button, variant: variant });
        button.contentItem = pillContentComponent.createObject(button, { control: button, variant: variant });
        button.leftPadding = Kirigami.Units.gridUnit;
        button.rightPadding = Kirigami.Units.gridUnit;
        button.topPadding = Kirigami.Units.smallSpacing;
        button.bottomPadding = Kirigami.Units.smallSpacing;
    }
    // Phones: the header's buttons (Kirigami's close button) with the design
    // system's round pressed state instead of Breeze's framed one.
    function styleIconButtons(item) {
        if (!item) {
            return;
        }
        for (const child of item.children) {
            if (child instanceof T.AbstractButton) {
                if (child.objectName !== "saldoRound") {
                    child.objectName = "saldoRound";
                    child.background = roundBackgroundComponent.createObject(child, { control: child });
                }
            } else {
                styleIconButtons(child);
            }
        }
    }
    property Component roundBackgroundComponent: Component {
        RoundButtonBackground {}
    }
    property Component pillBackgroundComponent: Component {
        PillBackground {}
    }
    property Component pillContentComponent: Component {
        PillContent {}
    }

    function apply() {
        if (!Platform.isPhone || !sheet) {
            return;
        }
        const s = sheet;
        // Breeze gives dialogs a gridUnit margin all around: at the bottom
        // edge Qt shrank the sheet by it and cut its content. Only the top one
        // stays, clear of the status bar.
        s.margins = 0;
        s.topMargin = Qt.binding(() => (s.parent ? s.parent.SafeArea.margins.top : 0) + Kirigami.Units.gridUnit);
        s.x = 0;
        s.width = Qt.binding(() => s.parent ? s.parent.width : 0);
        anchorBottom();
        // Clear of the gesture bar: a dialog's footer sits outside its
        // padding, at the very bottom, so the room goes into the footer
        // (or the padding when there is none).
        if (s.footer) {
            const base = s.footer.bottomPadding;
            s.footer.bottomPadding = Qt.binding(() => base + style.safeBottom());
        } else {
            s.bottomPadding = Qt.binding(() => style.safeBottom());
        }
        // Created on the popup's item: a Popup is no item, and visual objects
        // created on it warned they were not in the scene.
        s.background = backgroundComponent.createObject(s.contentItem.parent);
        // The title below the handle, its sides in line with the content.
        if (s.header) {
            s.header.topPadding = Kirigami.Units.gridUnit * 1.5;
            s.header.leftPadding = Kirigami.Units.gridUnit;
            s.header.rightPadding = Kirigami.Units.largeSpacing;
        }
        // Drag down to close: a strip over the sheet's top (handle and title),
        // above the header, which took the touches before.
        dragComponent.createObject(s.contentItem.parent);
        s.enter = enterComponent.createObject(s);
        s.exit = exitComponent.createObject(s);
    }

    property Component backgroundComponent: Component {
        SheetBackground {
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false
        }
    }
    // Drag down to close; let go early and it springs back. Taps still reach
    // the header's buttons (a drag only starts past the threshold).
    property Component dragComponent: Component {
        Item {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: Kirigami.Units.gridUnit * 3
            z: 1000

            // How far the sheet was dragged: the handler has already reset
            // its translation when it reports the release.
            property real dragged: 0

            DragHandler {
                target: null
                xAxis.enabled: false
                onTranslationChanged: {
                    if (!active) {
                        return;
                    }
                    const s = style.sheet;
                    parent.dragged = Math.max(0, translation.y);
                    s.y = Platform.keyboardTop(s.parent) - s.height + parent.dragged;
                }
                onActiveChanged: {
                    if (active) {
                        return;
                    }
                    const s = style.sheet;
                    if (parent.dragged > s.height / 4) {
                        s.close();
                    } else {
                        style.anchorBottom();
                    }
                    parent.dragged = 0;
                }
            }
        }
    }
    property Component enterComponent: Component {
        Transition {
            NumberAnimation {
                property: "y"
                from: style.sheet.parent ? style.sheet.parent.height : 0
                to: style.sheet.parent ? style.sheet.parent.height - style.sheet.height : 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }
    property Component exitComponent: Component {
        Transition {
            NumberAnimation {
                property: "y"
                to: style.sheet.parent ? style.sheet.parent.height : 0
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.InCubic
            }
        }
    }
}
