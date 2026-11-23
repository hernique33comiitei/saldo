// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// Income vs. expenses per month for the N months up to endMonth (oldest first).
class SALDOCORE_EXPORT CashflowModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int months READ months WRITE setMonths NOTIFY monthsChanged)
    // "yyyy-MM" of the last month shown; empty = current month
    Q_PROPERTY(QString endMonth READ endMonth WRITE setEndMonth NOTIFY monthsChanged)
    Q_PROPERTY(double maxValue READ maxValue NOTIFY summaryChanged)
    // Totals of endMonth (the last pair of bars).
    Q_PROPERTY(double endIncome READ endIncome NOTIFY summaryChanged)
    Q_PROPERTY(double endExpense READ endExpense NOTIFY summaryChanged)

public:
    explicit CashflowModel(QObject *parent = nullptr);

    int months() const;
    void setMonths(int months);
    QString endMonth() const;
    void setEndMonth(const QString &month);
    double maxValue() const;
    double endIncome() const;
    double endExpense() const;

Q_SIGNALS:
    void monthsChanged();

protected:
    QList<QVariantMap> fetchRows() override;

private:
    int m_months = 6;
    QString m_endMonth;
    double m_maxValue = 0;
    double m_endIncome = 0;
    double m_endExpense = 0;
};
