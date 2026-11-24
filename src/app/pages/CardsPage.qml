// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.saldo.core

RefreshablePage {
    id: page

    title: i18n("Credit Cards")

    actions: [
        Kirigami.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            shortcut: StandardKey.Refresh
            enabled: Credentials.configured && !SyncManager.running
            onTriggered: SyncManager.sync()
        }
    ]

    header: QQC2.Control {
        visible: list.count > 0
        padding: Kirigami.Units.largeSpacing
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
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
            RowLayout {
                Layout.fillWidth: true
                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("%1 used (%2)", Config.privacyMode ? Money.masked : Money.format(FinanceSummary.cardUsed), Money.percent(FinanceSummary.cardUsedRatio))
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideRight
                }
                QQC2.Label {
                    text: i18n("%1 available", Config.privacyMode ? Money.masked : Money.format(FinanceSummary.cardAvailable))
                    font: Kirigami.Theme.smallFont
                }
            }
        }
        background: Rectangle {
            color: Kirigami.Theme.alternateBackgroundColor
            Kirigami.Separator {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
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

        delegate: QQC2.ItemDelegate {
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
