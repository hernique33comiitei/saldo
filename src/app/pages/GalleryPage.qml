// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI

// The design system's catalog (`saldo --demo --page gallery`, on the phone
// `tools/phone-test.sh run --demo --page gallery`): every org.saldo.ui
// component in its states, to review them in light and dark on both
// platforms. A development page, reached only by --page; its texts are
// samples, not translated.
Kirigami.ScrollablePage {
    id: page

    Component.onCompleted: {
        if (UI.Platform.isPhone) {
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

    title: "Design system"

    // A titled block of the catalog.
    component Section: ColumnLayout {
        property alias title: sectionTitle.text
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        QQC2.Label {
            id: sectionTitle
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit
            font.family: "monospace"
            wrapMode: Text.Wrap
            opacity: 0.6
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.gridUnit

        Section {
            title: "UI.Card: title + action · title · tile (no title)"
            UI.Card {
                Layout.fillWidth: true
                title: "Credit limit"
                headerActions: [
                    Kirigami.Action {
                        text: "Cards"
                        icon.name: "go-next-symbolic"
                    }
                ]
                QQC2.Label {
                    text: "Content goes into a column."
                }
            }
            UI.Card {
                Layout.fillWidth: true
                title: "Spending by category"
                QQC2.Label {
                    text: "A card with a title only."
                }
            }
            UI.Card {
                Layout.fillWidth: true
                UI.IconBadge {
                    source: "view-financial-account-investment"
                }
                QQC2.Label {
                    text: "A tile: no title, no header."
                }
            }
        }

        Section {
            title: "UI.IconBadge: highlight · positive · neutral · negative · disabled"
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: [Kirigami.Theme.highlightColor, Kirigami.Theme.positiveTextColor, Kirigami.Theme.neutralTextColor,
                            Kirigami.Theme.negativeTextColor, Kirigami.Theme.disabledTextColor]
                    delegate: UI.IconBadge {
                        required property color modelData
                        source: "view-financial-account-credit-card"
                        tint: modelData
                    }
                }
            }
        }

        Section {
            title: "UI.Chip: checked · unchecked · drop-down · disabled"
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                UI.Chip {
                    text: "All"
                    checked: true
                }
                UI.Chip {
                    text: "Income"
                }
                UI.Chip {
                    text: "All months"
                    dropDown: true
                }
                UI.Chip {
                    text: "Disabled"
                    enabled: false
                }
            }
        }

        Section {
            title: "UI.DrawerItem: active · idle"
            UI.DrawerItem {
                text: "Settings"
                iconName: "configure"
                active: true
            }
            UI.DrawerItem {
                text: "About Saldo"
                iconName: "help-about"
            }
        }

        Section {
            title: "UI.SummaryHeader"
            UI.SummaryHeader {
                Layout.fillWidth: true
                QQC2.Label {
                    text: "Total in accounts · R$ 23.650,65"
                }
            }
        }

        Section {
            title: "UI.SectionHeader"
            UI.SectionHeader {
                Layout.fillWidth: true
                section: "Friday, November 20, 2026"
            }
        }

        Section {
            title: "UI.TabBar"
            UI.TabBar {
                Layout.fillWidth: true
                actions: [
                    Kirigami.Action {
                        text: "Overview"
                        icon.name: "view-statistics"
                        checked: true
                    },
                    Kirigami.Action {
                        text: "Accounts"
                        icon.name: "view-bank"
                    },
                    Kirigami.Action {
                        text: "Cards"
                        icon.name: "view-financial-account-credit-card"
                    }
                ]
            }
        }

        Item {
            implicitHeight: Kirigami.Units.gridUnit
        }
    }
}
