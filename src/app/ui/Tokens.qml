// SPDX-License-Identifier: MIT
pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami

// Design tokens of Saldo's design system (org.saldo.ui): every radius, tint,
// type size and brand color the components use, by role. Spacing stays
// Kirigami.Units (gridUnit, largeSpacing, smallSpacing); colors come from
// Kirigami.Theme, tinted with tint() by the amounts below.
QtObject {
    // Corner radii.
    readonly property real radiusCard: Kirigami.Units.gridUnit
    readonly property real radiusHero: Kirigami.Units.gridUnit * 1.25
    readonly property real radiusInner: Kirigami.Units.gridUnit * 0.75

    // How much of a color goes over the background (tint()).
    readonly property real tintBar: 0.05        // tab bar
    readonly property real tintSurface: 0.06    // cards
    readonly property real tintChip: 0.12       // info chips, colored tiles, the open setup step
    readonly property real tintBadge: 0.18      // icon circles
    readonly property real tintSelected: 0.25   // a checked chip
    readonly property real tintActive: 0.28     // the current tab, the open drawer page
    readonly property real tintOutline: 0.25    // an unchecked chip's border
    readonly property real tintPressed: 0.1
    readonly property real tintTrack: 0.1       // the empty part of a bar
    readonly property real tintIconIdle: 0.75   // a tab's icon when not current

    // Type scale, multipliers of the default font's point size.
    readonly property real fontMoneyLarge: 2.4
    readonly property real fontMoneyMedium: 1.3
    readonly property real fontTitle: 1.1
    readonly property real fontSection: 0.9
    readonly property real fontCaption: 0.85

    // Sizes.
    readonly property real touchTarget: Kirigami.Units.gridUnit * 2
    readonly property real chipHeight: Kirigami.Units.gridUnit * 2
    readonly property real drawerItemHeight: Kirigami.Units.gridUnit * 2.75
    readonly property real tabPillWidth: Kirigami.Units.gridUnit * 3.5
    readonly property real tabPillHeight: Kirigami.Units.gridUnit * 1.75
    readonly property real barThickness: Kirigami.Units.smallSpacing * 2.5
    readonly property real tabBarMaxWidth: Kirigami.Units.gridUnit * 30
    readonly property real heroPadding: Kirigami.Units.gridUnit * 1.25

    // The app icon's green, darkened for white text at 4.5:1 or more
    // (#17845a 4.7:1; the icon's own #1b9e6b gave 3.4:1). BalanceHero only.
    readonly property color brandStart: "#136b49"
    readonly property color brandEnd: "#17845a"

    // A color over a background, by one of the amounts above. (Font sizes:
    // Kirigami.Theme.defaultFont.pointSize * a scale above, in the item, since
    // Kirigami.Theme only attaches to items.)
    function tint(background: color, over: color, amount: real): color {
        return Kirigami.ColorUtils.tintWithAlpha(background, over, amount);
    }
}
