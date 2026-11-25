// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.saldo.ui as UI
import org.saldo.core

Kirigami.ApplicationWindow {
    id: root

    property string initialPage: ""
    property string currentPage: ""
    readonly property bool setupComplete: Credentials.configured && Config.itemIds.length > 0
    property bool firstRunChecked: false
    // The first page exists and has its size; Android hides its splash screen
    // after a frame with it (main.cpp).
    readonly property bool pageReady: pageStack.currentItem !== null
                                      && pageStack.currentItem.width > 0 && pageStack.currentItem.height > 0
    // Phones: the five sections as tabs at the bottom, as current Android apps
    // do; the drawer keeps the setup guide, settings and about.
    readonly property bool tabs: Kirigami.Settings.isMobile

    // First run: open the setup guide instead of an empty overview.
    function checkFirstRun() {
        if (firstRunChecked || !Credentials.loaded) {
            return;
        }
        firstRunChecked = true;
        if (initialPage.length === 0 && !setupComplete && !FinanceSummary.hasData) {
            showPage("setup");
        }
    }

    function showPage(name: string) {
        const pages = {
            "overview": tabs ? phoneOverviewPage : overviewPage,
            "accounts": accountsPage,
            "cards": cardsPage,
            "transactions": transactionsPage,
            "investments": investmentsPage,
            "settings": settingsPage,
            "setup": setupPage,
            "about": aboutPage,
            // The design system's catalog: --page gallery only, no menu entry.
            "gallery": galleryPage
        };
        const page = pages[name] ?? overviewPage;
        currentPage = pages[name] ? name : "overview";
        pageStack.clear();
        pageStack.push(page);
        if (globalDrawer.modal) {
            globalDrawer.close();
        }
    }

    title: i18n("Saldo")
    width: Kirigami.Units.gridUnit * 50
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 20
    minimumHeight: Kirigami.Units.gridUnit * 24

    // Android: draw behind the status and navigation bars, which turn
    // transparent, as current apps do; Kirigami pads the header and the tabs
    // by the safe areas.
    flags: Qt.platform.os === "android" ? Qt.Window | Qt.ExpandedClientAreaHint : Qt.Window

    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.SingleColumn
    // Page actions in the header on phones too (Kirigami's mobile default is
    // a toolbar of their own at the bottom, stacked on the tabs).
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
    pageStack.globalToolBar.showNavigationButtons: Kirigami.ApplicationHeaderStyle.ShowBackButton

    Component.onCompleted: {
        if (tabs) {
            // Phones: a flat header in the pages' own (View) colors, no
            // separator, a bit taller, as current Android apps (pages also take
            // PhoneTitle and the View colors).
            // Set here so the desktop keeps Kirigami's defaults untouched.
            const bar = pageStack.globalToolBar;
            bar.colorSet = Kirigami.Theme.View;
            bar.separatorVisible = false;
            bar.preferredHeight = Qt.binding(() => Kirigami.Units.gridUnit * 3.5 + (bar.safeArea ? bar.safeArea.margins.top : 0));
        }
        showPage(initialPage.length > 0 ? initialPage : "overview");
        checkFirstRun();
    }

    // Phones: Android's back closes an open drawer (nothing else handles it
    // there, so the app closed instead).
    onClosing: close => {
        if (tabs && globalDrawer.drawerOpen) {
            close.accepted = false;
            globalDrawer.close();
        }
    }

    // Phones: Kirigami's own header and drawer buttons in the design
    // system's look.
    UI.PhoneChrome {
        window: root
    }

    Connections {
        target: Credentials
        function onConfiguredChanged() {
            root.checkFirstRun();
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        id: drawer

        isMenu: false
        modal: !root.wideScreen
        // Phones: the header's menu button opens it; no close button beside it.
        handleVisible: modal && !(root.tabs && drawerOpen)
        onModalChanged: drawerOpen = !modal

        // Phones: wider, rounded on its open side, with PhoneDrawerContent as
        // its header (the sections are tabs there). Set here so the desktop
        // keeps the style's drawer untouched.
        Component.onCompleted: {
            if (!root.tabs) {
                return;
            }
            Kirigami.Theme.colorSet = Kirigami.Theme.View;
            width = Qt.binding(() => Math.min(root.width * 0.82, Kirigami.Units.gridUnit * 17));
            leftPadding = Qt.binding(() => (drawer.parent ? drawer.parent.SafeArea.margins.left : 0) + Kirigami.Units.largeSpacing);
            rightPadding = Kirigami.Units.largeSpacing;
            // Created on the drawer's item: a Popup is no item, and visual
            // objects created on it warned they were not in the scene.
            background = phoneDrawerBackground.createObject(drawer.contentItem);
            header = phoneDrawerHeader.createObject(drawer.contentItem);
        }

        header: Kirigami.AbstractApplicationHeader {
            visible: !root.tabs
            contentItem: RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Kirigami.Units.largeSpacing
                    rightMargin: Kirigami.Units.largeSpacing
                }
                spacing: Kirigami.Units.largeSpacing

                Image {
                    source: "qrc:/icons/saldo.svg"
                    sourceSize.width: Kirigami.Units.iconSizes.medium
                    sourceSize.height: Kirigami.Units.iconSizes.medium
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                Kirigami.Heading {
                    Layout.fillWidth: true
                    text: i18n("Saldo")
                    level: 2
                    elide: Text.ElideRight
                }
            }
        }

        actions: [
            Kirigami.Action {
                text: i18n("Connect Meu Pluggy")
                icon.name: "wallet-open"
                visible: !root.setupComplete && !root.tabs
                checked: root.currentPage === "setup"
                onTriggered: root.showPage("setup")
            },
            Kirigami.Action {
                text: i18n("Overview")
                icon.name: "view-statistics"
                visible: !root.tabs
                checked: root.currentPage === "overview"
                shortcut: "Ctrl+1"
                onTriggered: root.showPage("overview")
            },
            Kirigami.Action {
                text: i18n("Accounts")
                icon.name: "view-bank"
                visible: !root.tabs
                checked: root.currentPage === "accounts"
                shortcut: "Ctrl+2"
                onTriggered: root.showPage("accounts")
            },
            Kirigami.Action {
                text: i18n("Credit Cards")
                icon.name: "view-financial-account-credit-card"
                visible: !root.tabs
                checked: root.currentPage === "cards"
                shortcut: "Ctrl+3"
                onTriggered: root.showPage("cards")
            },
            Kirigami.Action {
                text: i18n("Transactions")
                icon.name: "view-financial-list"
                visible: !root.tabs
                checked: root.currentPage === "transactions"
                shortcut: "Ctrl+4"
                onTriggered: root.showPage("transactions")
            },
            Kirigami.Action {
                text: i18n("Investments")
                icon.name: "view-financial-account-investment"
                visible: !root.tabs
                checked: root.currentPage === "investments"
                shortcut: "Ctrl+5"
                onTriggered: root.showPage("investments")
            },
            Kirigami.Action {
                separator: true
                visible: !root.tabs
            },
            Kirigami.Action {
                text: i18n("Settings")
                icon.name: "configure"
                visible: !root.tabs
                checked: root.currentPage === "settings"
                shortcut: StandardKey.Preferences
                onTriggered: root.showPage("settings")
            },
            Kirigami.Action {
                text: i18n("About Saldo")
                icon.name: "help-about"
                visible: !root.tabs
                checked: root.currentPage === "about"
                onTriggered: root.showPage("about")
            }
        ]
    }

    // No footer at all on the desktop: Kirigami makes the sidebar drawer shorter
    // by the footer's height even when the footer is hidden (it ended 120 px
    // above the window's bottom edge).
    footer: root.tabs ? tabBar : null

    UI.TabBar {
        id: tabBar
        visible: root.tabs
        actions: [
            Kirigami.Action {
                text: i18nc("@title:tab short label, about 8 characters fit on phones", "Overview")
                icon.name: "view-statistics"
                checked: root.currentPage === "overview"
                onTriggered: root.showPage("overview")
            },
            Kirigami.Action {
                text: i18nc("@title:tab short label, about 8 characters fit on phones", "Accounts")
                icon.name: "view-bank"
                checked: root.currentPage === "accounts"
                onTriggered: root.showPage("accounts")
            },
            Kirigami.Action {
                text: i18nc("@title:tab short label, about 8 characters fit on phones", "Cards")
                icon.name: "view-financial-account-credit-card"
                checked: root.currentPage === "cards"
                onTriggered: root.showPage("cards")
            },
            Kirigami.Action {
                text: i18nc("@title:tab short label for the transactions list, about 8 characters fit on phones", "Activity")
                icon.name: "view-financial-list"
                checked: root.currentPage === "transactions"
                onTriggered: root.showPage("transactions")
            },
            Kirigami.Action {
                text: i18nc("@title:tab short label for the investments page, about 8 characters fit on phones", "Invest")
                icon.name: "view-financial-account-investment"
                checked: root.currentPage === "investments"
                onTriggered: root.showPage("investments")
            }
        ]
    }

    Component {
        id: overviewPage
        OverviewPage {}
    }
    Component {
        id: galleryPage
        GalleryPage {}
    }
    Component {
        id: phoneOverviewPage
        PhoneOverviewPage {}
    }
    Component {
        id: phoneDrawerHeader
        PhoneDrawerContent {
            currentPage: root.currentPage
            setupComplete: root.setupComplete
            onPageRequested: name => root.showPage(name)
        }
    }
    Component {
        id: phoneDrawerBackground
        Rectangle {
            color: Kirigami.Theme.backgroundColor
            topRightRadius: UI.Tokens.radiusHero
            bottomRightRadius: UI.Tokens.radiusHero
        }
    }
    Component {
        id: accountsPage
        AccountsPage {}
    }
    Component {
        id: cardsPage
        CardsPage {}
    }
    Component {
        id: transactionsPage
        TransactionsPage {}
    }
    Component {
        id: investmentsPage
        InvestmentsPage {}
    }
    Component {
        id: settingsPage
        SettingsPage {}
    }
    Component {
        id: setupPage
        SetupPage {}
    }
    Component {
        id: aboutPage
        AboutPage {}
    }
}
