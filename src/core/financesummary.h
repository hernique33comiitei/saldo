// SPDX-License-Identifier: MIT
#pragma once

#include "cardtotals.h"
#include "saldocore_export.h"

#include <QDateTime>
#include <QObject>
#include <QQmlEngine>
#include <QVariantList>

// Headline numbers for the overview page and the widget. Reloads whenever the
// cache changes (in this process or in the other one).
class SALDOCORE_EXPORT FinanceSummary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool hasData READ hasData NOTIFY changed)
    Q_PROPERTY(double totalCash READ totalCash NOTIFY changed)
    Q_PROPERTY(double totalInvested READ totalInvested NOTIFY changed)
    Q_PROPERTY(double cardLimit READ cardLimit NOTIFY changed)
    Q_PROPERTY(double cardUsed READ cardUsed NOTIFY changed)
    Q_PROPERTY(double cardAvailable READ cardAvailable NOTIFY changed)
    Q_PROPERTY(double cardUsedRatio READ cardUsedRatio NOTIFY changed)
    // What the cards have to be paid next: open bills + closed bills not due yet.
    Q_PROPERTY(double nextBills READ nextBills NOTIFY changed)
    Q_PROPERTY(QDate nextBillDue READ nextBillDue NOTIFY changed)
    Q_PROPERTY(double monthIncome READ monthIncome NOTIFY changed)
    Q_PROPERTY(double monthExpenses READ monthExpenses NOTIFY changed)
    Q_PROPERTY(int connectionCount READ connectionCount NOTIFY changed)
    Q_PROPERTY(int accountCount READ accountCount NOTIFY changed)
    Q_PROPERTY(int cardCount READ cardCount NOTIFY changed)
    Q_PROPERTY(int investmentCount READ investmentCount NOTIFY changed)
    Q_PROPERTY(QDateTime dataUpdatedAt READ dataUpdatedAt NOTIFY changed)
    Q_PROPERTY(QDateTime nextAutoSyncAt READ nextAutoSyncAt NOTIFY changed)
    Q_PROPERTY(QStringList attention READ attention NOTIFY changed)
    Q_PROPERTY(QVariantList months READ months NOTIFY changed)

public:
    static FinanceSummary *instance();
    static FinanceSummary *create(QQmlEngine *, QJSEngine *);

    bool hasData() const;
    double totalCash() const;
    double totalInvested() const;
    double cardLimit() const;
    double cardUsed() const;
    double cardAvailable() const;
    double cardUsedRatio() const;
    double nextBills() const;
    QDate nextBillDue() const;
    double monthIncome() const;
    double monthExpenses() const;
    int connectionCount() const;
    int accountCount() const;
    int cardCount() const;
    int investmentCount() const;
    QDateTime dataUpdatedAt() const;
    QDateTime nextAutoSyncAt() const;
    QStringList attention() const;
    QVariantList months() const;

    Q_INVOKABLE void reload();

Q_SIGNALS:
    void changed();

private:
    explicit FinanceSummary(QObject *parent = nullptr);
    void scheduleReload();

    bool m_reloadPending = false;
    double m_totalCash = 0;
    double m_totalInvested = 0;
    CardTotals m_cards;
    double m_monthIncome = 0;
    double m_monthExpenses = 0;
    int m_connectionCount = 0;
    int m_accountCount = 0;
    int m_cardCount = 0;
    int m_investmentCount = 0;
    QDateTime m_dataUpdatedAt;
    QDateTime m_nextAutoSyncAt;
    double m_nextBills = 0;
    QDate m_nextBillDue;
    QStringList m_attention;
    QVariantList m_months;
};
