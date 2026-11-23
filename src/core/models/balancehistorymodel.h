// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// Daily total of the bank accounts over the last N days (oldest first), from
// the balances Saldo records on every sync (Database::recordBalanceSnapshot).
//
// Pluggy has no balance history, and rebuilding it from transactions does not
// work: some banks move money (e.g. automatic savings) without transactions,
// which made the rebuilt history go below zero.
class SALDOCORE_EXPORT BalanceHistoryModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int days READ days WRITE setDays NOTIFY daysChanged)
    Q_PROPERTY(double minValue READ minValue NOTIFY summaryChanged)
    Q_PROPERTY(double maxValue READ maxValue NOTIFY summaryChanged)
    // First and last day with a value (the x axis ends).
    Q_PROPERTY(QDate firstDay READ firstDay NOTIFY summaryChanged)
    Q_PROPERTY(QDate lastDay READ lastDay NOTIFY summaryChanged)
    Q_PROPERTY(double firstValue READ firstValue NOTIFY summaryChanged)
    Q_PROPERTY(double lastValue READ lastValue NOTIFY summaryChanged)

public:
    explicit BalanceHistoryModel(QObject *parent = nullptr);

    int days() const;
    void setDays(int days);
    double minValue() const;
    double maxValue() const;
    QDate firstDay() const;
    QDate lastDay() const;
    double firstValue() const;
    double lastValue() const;

Q_SIGNALS:
    void daysChanged();

protected:
    QList<QVariantMap> fetchRows() override;

private:
    int m_days = 90;
    double m_minValue = 0;
    double m_maxValue = 0;
    QDate m_firstDay;
    QDate m_lastDay;
    double m_firstValue = 0;
    double m_lastValue = 0;
};
