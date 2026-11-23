// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// Expenses of one month grouped by category (largest first, the tail folded
// into "Other"). Movements between own accounts are left out.
class SALDOCORE_EXPORT CategorySpendModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

    // "yyyy-MM"; empty = current month
    Q_PROPERTY(QString month READ month WRITE setMonth NOTIFY monthChanged)
    Q_PROPERTY(int maximumCategories READ maximumCategories WRITE setMaximumCategories NOTIFY monthChanged)
    Q_PROPERTY(double total READ total NOTIFY summaryChanged)

public:
    explicit CategorySpendModel(QObject *parent = nullptr);

    QString month() const;
    void setMonth(const QString &month);
    int maximumCategories() const;
    void setMaximumCategories(int maximum);
    double total() const;

Q_SIGNALS:
    void monthChanged();

protected:
    QList<QVariantMap> fetchRows() override;

private:
    QString m_month;
    int m_maximumCategories = 6;
    double m_total = 0;
};
