// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.saldo.core

PlasmaExtras.Representation {
    id: full

    readonly property var tabPages: ["overview", "cards", "transactions"]

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 24
    Layout.preferredWidth: Kirigami.Units.gridUnit * 26
    Layout.preferredHeight: Kirigami.Units.gridUnit * 32

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: "saldo"
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 3
                        text: i18nd("saldo", "Saldo")
                        elide: Text.ElideRight
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                        text: {
                            if (SyncManager.running) {
                                return SyncManager.progressText;
                            }
                            if (!FinanceSummary.hasData) {
                                return "";
                            }
                            const parts = [];
                            if (FinanceSummary.dataUpdatedAt.getTime && !isNaN(FinanceSummary.dataUpdatedAt.getTime())) {
                                parts.push(i18nd("saldo", "Banks updated %1", Money.relativeTime(FinanceSummary.dataUpdatedAt)));
                            }
                            parts.push(i18ndp("saldo", "%1 connection", "%1 connections", FinanceSummary.connectionCount));
                            return parts.join(" · ");
                        }
                    }
                }

                PlasmaComponents3.BusyIndicator {
                    visible: SyncManager.running
                    running: visible
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }
                PlasmaComponents3.ToolButton {
                    visible: !SyncManager.running
                    enabled: Credentials.configured
                    icon.name: "view-refresh"
                    text: i18nd("saldo", "Refresh")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: SyncManager.sync()
                }
                PlasmaComponents3.ToolButton {
                    icon.name: Config.privacyMode ? "view-visible" : "view-hidden"
                    text: Config.privacyMode ? i18nd("saldo", "Show Values") : i18nd("saldo", "Hide Values")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    checkable: true
                    checked: Config.privacyMode
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onToggled: Config.privacyMode = checked
                }
                PlasmaComponents3.ToolButton {
                    visible: Launcher.canOpenApp
                    icon.name: "window-new"
                    text: i18nd("saldo", "Open Saldo")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: {
                        if (Launcher.openApp(full.tabPages[tabs.currentIndex] ?? "")) {
                            root.expanded = false;
                        }
                    }
                }
            }

            PlasmaComponents3.TabBar {
                id: tabs
                Layout.fillWidth: true
                visible: FinanceSummary.hasData

                PlasmaComponents3.TabButton {
                    text: i18nd("saldo", "Summary")
                }
                PlasmaComponents3.TabButton {
                    text: i18nd("saldo", "Cards")
                }
                PlasmaComponents3.TabButton {
                    text: i18nd("saldo", "Transactions")
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            type: Kirigami.MessageType.Error
            visible: !SyncManager.running && SyncManager.lastError.length > 0
            text: SyncManager.lastError
            actions: [
                Kirigami.Action {
                    text: i18nd("saldo", "Dismiss")
                    icon.name: "dialog-ok-apply"
                    onTriggered: SyncManager.dismissError()
                }
            ]
        }

        Repeater {
            model: FinanceSummary.attention
            delegate: Kirigami.InlineMessage {
                required property string modelData
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                type: Kirigami.MessageType.Warning
                visible: true
                text: modelData
            }
        }

        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.gridUnit
            visible: !FinanceSummary.hasData
            iconName: Credentials.configured ? "view-refresh" : "saldo"
            text: {
                if (!Credentials.configured) {
                    return i18nd("saldo", "Saldo is not set up");
                }
                return SyncManager.running ? i18nd("saldo", "Downloading your data…") : i18nd("saldo", "No data yet");
            }
            explanation: Credentials.configured
                ? i18nd("saldo", "Your accounts appear here as soon as the first sync finishes.")
                : i18nd("saldo", "Add your Meu Pluggy credentials and connections in the Saldo app.")
            helpfulAction: QQC2.Action {
                enabled: Credentials.configured ? !SyncManager.running : Launcher.canOpenApp
                text: Credentials.configured ? i18nd("saldo", "Sync Now") : i18nd("saldo", "Set Up Saldo")
                icon.name: Credentials.configured ? "view-refresh" : "configure"
                onTriggered: {
                    if (Credentials.configured) {
                        SyncManager.sync();
                    } else {
                        if (Launcher.openApp("setup")) {
                            root.expanded = false;
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: FinanceSummary.hasData
            currentIndex: tabs.currentIndex

            // Summary
            PlasmaComponents3.ScrollView {
                id: summaryScroll
                contentWidth: availableWidth
                PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                ColumnLayout {
                    width: summaryScroll.availableWidth
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.largeSpacing
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        spacing: 0
                        PlasmaComponents3.Label {
                            text: i18nd("saldo", "In accounts")
                            opacity: 0.7
                        }
                        MoneyLabel {
                            value: FinanceSummary.totalCash
                            warnNegative: true
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                            font.weight: Font.DemiBold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        SummaryRow {
                            Layout.fillWidth: true
                            visible: root.showInvestments && FinanceSummary.investmentCount > 0
                            iconName: "view-financial-account-investment"
                            label: i18nd("saldo", "Invested")
                            value: FinanceSummary.totalInvested
                        }
                        SummaryRow {
                            Layout.fillWidth: true
                            visible: FinanceSummary.cardCount > 0
                            iconName: "view-financial-account-credit-card"
                            label: i18nd("saldo", "Next bills")
                            value: FinanceSummary.nextBills
                        }
                    }

                    Kirigami.ListSectionHeader {
                        Layout.fillWidth: true
                        visible: FinanceSummary.cardLimit > 0
                        text: i18nd("saldo", "Credit limit")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        visible: FinanceSummary.cardLimit > 0
                        spacing: Kirigami.Units.largeSpacing * 2

                        LimitDonut {
                            implicitWidth: Kirigami.Units.gridUnit * 5
                            used: FinanceSummary.cardUsed
                            limit: FinanceSummary.cardLimit
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            SummaryRow {
                                Layout.fillWidth: true
                                label: i18nd("saldo", "Total limit")
                                value: FinanceSummary.cardLimit
                                emphasized: true
                            }
                            SummaryRow {
                                Layout.fillWidth: true
                                label: i18nd("saldo", "Used")
                                value: FinanceSummary.cardUsed
                            }
                            SummaryRow {
                                Layout.fillWidth: true
                                label: i18nd("saldo", "Available")
                                value: FinanceSummary.cardAvailable
                            }
                        }
                    }

                    Kirigami.ListSectionHeader {
                        Layout.fillWidth: true
                        text: i18nd("saldo", "This month")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Layout.bottomMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        SummaryRow {
                            Layout.fillWidth: true
                            iconName: "view-financial-category-income"
                            label: i18nd("saldo", "Income")
                            value: FinanceSummary.monthIncome
                        }
                        SummaryRow {
                            Layout.fillWidth: true
                            iconName: "view-financial-category-expense"
                            label: i18nd("saldo", "Expenses")
                            value: FinanceSummary.monthExpenses
                        }
                        CashflowChart {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            chartHeight: Kirigami.Units.gridUnit * 5
                            model: CashflowModel {
                                months: 6
                            }
                        }
                    }
                }
            }

            // Cards
            PlasmaComponents3.ScrollView {
                PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff
                ListView {
                    id: cardsList
                    clip: true
                    model: AccountsModel {
                        type: "CREDIT"
                    }
                    delegate: PlasmaComponents3.ItemDelegate {
                        id: cardDelegate
                        required property var model

                        width: ListView.view.width
                        topPadding: Kirigami.Units.largeSpacing
                        bottomPadding: Kirigami.Units.largeSpacing
                        onClicked: {
                            if (Launcher.openApp("cards")) {
                                root.expanded = false;
                            }
                        }
                        contentItem: CardContent {
                            name: cardDelegate.model.name
                            numberLabel: cardDelegate.model.numberLabel
                            cardLabel: cardDelegate.model.cardLabel
                            institution: cardDelegate.model.institution
                            limit: cardDelegate.model.creditLimit
                            used: cardDelegate.model.usedCredit
                            available: cardDelegate.model.availableCreditLimit
                            ratio: cardDelegate.model.usedRatio
                            sharedLimit: cardDelegate.model.sharedLimit
                            included: cardDelegate.model.included
                        }
                    }

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 2
                        visible: cardsList.count === 0
                        iconName: "view-financial-account-credit-card"
                        text: i18nd("saldo", "No credit cards")
                    }
                }
            }

            // Transactions
            ColumnLayout {
                spacing: 0

                PlasmaComponents3.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                    ListView {
                        id: transactionsList
                        clip: true
                        model: TransactionsModel {
                            limit: 40
                        }
                        section.property: "dateLabel"
                        section.delegate: Kirigami.ListSectionHeader {
                            required property string section
                            width: ListView.view.width
                            text: section
                        }
                        delegate: PlasmaComponents3.ItemDelegate {
                            id: txDelegate
                            required property var model

                            width: ListView.view.width
                            hoverEnabled: false
                            down: false
                            contentItem: TransactionContent {
                                description: txDelegate.model.description
                                categoryLabel: txDelegate.model.categoryLabel
                                categoryIcon: txDelegate.model.categoryIcon
                                accountName: txDelegate.model.accountName
                                installment: txDelegate.model.installment
                                amount: txDelegate.model.amount
                                currency: txDelegate.model.currency
                                pending: txDelegate.model.pending
                                internal: txDelegate.model.internal
                            }
                        }

                        PlasmaExtras.PlaceholderMessage {
                            anchors.centerIn: parent
                            width: parent.width - Kirigami.Units.gridUnit * 2
                            visible: transactionsList.count === 0
                            iconName: "view-financial-list"
                            text: i18nd("saldo", "No transactions")
                        }
                    }
                }

                PlasmaComponents3.Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.margins: Kirigami.Units.smallSpacing
                    visible: Launcher.canOpenApp
                    text: i18nd("saldo", "Show All Transactions")
                    icon.name: "view-financial-list"
                    onClicked: {
                        if (Launcher.openApp("transactions")) {
                            root.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
