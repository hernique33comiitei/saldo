// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

RefreshablePage {
    id: page

    // Phones: PhoneCardRow rows.
    readonly property bool phone: Kirigami.Settings.isMobile

    title: i18n("Credit Cards")

    actions: [
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            // No shortcuts on phones: a menu showed them over the text ("Ctrl+H").
            shortcut: Kirigami.Settings.isMobile ? "" : StandardKey.Refresh
            displayHint: page.phone ? Kirigami.DisplayHint.IconOnly : Kirigami.DisplayHint.NoPreference
            enabled: Credentials.configured && !SyncManager.running
            onTriggered: SyncManager.sync()
        }
    ]

    header: ListSummaryHeader {
        visible: list.count > 0
        SummaryRow {
            Layout.fillWidth: true
            iconName: "view-financial-account-credit-card"
            label: i18n("Overall limit")
            value: FinanceSummary.cardLimit
            emphasized: true
        }
        LimitBar {
            Layout.fillWidth: true
            ratio: FinanceSummary.cardUsedRatio
        }
        GridLayout {
            Layout.fillWidth: true
            // Phones: one under the other when both do not fit side by side
            // (decided from the header's width, set by the page).
            columns: page.phone && width < usedLabel.implicitWidth + availableLabel.implicitWidth + columnSpacing ? 1 : 2
            QQC2.Label {
                id: usedLabel
                Layout.fillWidth: true
                text: i18n("%1 used (%2)", Config.privacyMode ? Money.masked : Money.format(FinanceSummary.cardUsed), Money.percent(FinanceSummary.cardUsedRatio))
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            QQC2.Label {
                id: availableLabel
                text: i18n("%1 available", Config.privacyMode ? Money.masked : Money.format(FinanceSummary.cardAvailable))
                font: Kirigami.Theme.smallFont
            }
        }
    }

    Component {
        id: desktopRow
        QQC2.ItemDelegate {
            id: delegate
            required property var model
            required property int index

            width: ListView.view.width
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            onClicked: applicationWindow().pageStack.push(detailComponent, {
                accountId: model.accountId,
                card: cards.get(index)
            })

            contentItem: CardContent {
                name: delegate.model.name
                numberLabel: delegate.model.numberLabel
                cardLabel: delegate.model.cardLabel
                institution: delegate.model.institution
                limit: delegate.model.creditLimit
                used: delegate.model.usedCredit
                available: delegate.model.availableCreditLimit
                ratio: delegate.model.usedRatio
                sharedLimit: delegate.model.sharedLimit
                included: delegate.model.included
            }
        }
    }
    Component {
        id: phoneRow
        QQC2.ItemDelegate {
            id: delegate
            required property var model
            required property int index

            width: ListView.view.width
            leftPadding: Kirigami.Units.gridUnit
            rightPadding: Kirigami.Units.gridUnit
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            onClicked: applicationWindow().pageStack.push(detailComponent, {
                accountId: model.accountId,
                card: cards.get(index)
            })

            contentItem: PhoneCardRow {
                name: delegate.model.name
                numberLabel: delegate.model.numberLabel
                cardLabel: delegate.model.cardLabel
                institution: delegate.model.institution
                limit: delegate.model.creditLimit
                used: delegate.model.usedCredit
                available: delegate.model.availableCreditLimit
                ratio: delegate.model.usedRatio
                sharedLimit: delegate.model.sharedLimit
                included: delegate.model.included
            }
        }
    }

    ListView {
        id: list

        spacing: 0
        model: AccountsModel {
            id: cards
            type: "CREDIT"
        }

        delegate: page.phone ? phoneRow : desktopRow

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: list.count === 0
            icon.name: "view-financial-account-credit-card"
            text: i18n("No credit cards")
            explanation: i18n("Credit cards from your Meu Pluggy connections show up here after a sync.")
        }
    }

    Component {
        id: detailComponent
        CardDetailPage {}
    }
}
