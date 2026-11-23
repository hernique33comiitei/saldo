// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
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
            "overview": overviewPage,
            "accounts": accountsPage,
            "cards": cardsPage,
            "transactions": transactionsPage,
            "investments": investmentsPage,
            "settings": settingsPage,
            "setup": setupPage,
            "about": aboutPage
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

    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.SingleColumn
    pageStack.globalToolBar.showNavigationButtons: Kirigami.ApplicationHeaderStyle.ShowBackButton

    Component.onCompleted: {
        showPage(initialPage.length > 0 ? initialPage : "overview");
        checkFirstRun();
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
        handleVisible: modal
        onModalChanged: drawerOpen = !modal

        header: Kirigami.AbstractApplicationHeader {
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
                visible: !root.setupComplete
                checked: root.currentPage === "setup"
                onTriggered: root.showPage("setup")
            },
            Kirigami.Action {
                text: i18n("Overview")
                icon.name: "view-statistics"
                checked: root.currentPage === "overview"
                shortcut: "Ctrl+1"
                onTriggered: root.showPage("overview")
            },
            Kirigami.Action {
                text: i18n("Accounts")
                icon.name: "view-bank"
                checked: root.currentPage === "accounts"
                shortcut: "Ctrl+2"
                onTriggered: root.showPage("accounts")
            },
            Kirigami.Action {
                text: i18n("Credit Cards")
                icon.name: "view-financial-account-credit-card"
                checked: root.currentPage === "cards"
                shortcut: "Ctrl+3"
                onTriggered: root.showPage("cards")
            },
            Kirigami.Action {
                text: i18n("Transactions")
                icon.name: "view-financial-list"
                checked: root.currentPage === "transactions"
                shortcut: "Ctrl+4"
                onTriggered: root.showPage("transactions")
            },
            Kirigami.Action {
                text: i18n("Investments")
                icon.name: "view-financial-account-investment"
                checked: root.currentPage === "investments"
                shortcut: "Ctrl+5"
                onTriggered: root.showPage("investments")
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                text: i18n("Settings")
                icon.name: "configure"
                checked: root.currentPage === "settings"
                shortcut: StandardKey.Preferences
                onTriggered: root.showPage("settings")
            },
            Kirigami.Action {
                text: i18n("About Saldo")
                icon.name: "help-about"
                checked: root.currentPage === "about"
                onTriggered: root.showPage("about")
            }
        ]
    }

    Component {
        id: overviewPage
        OverviewPage {}
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
