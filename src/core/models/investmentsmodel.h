// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// Investments (excluding fully withdrawn ones), grouped by type.
class SALDOCORE_EXPORT InvestmentsModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(double total READ total NOTIFY summaryChanged)

public:
    explicit InvestmentsModel(QObject *parent = nullptr);

    double total() const;

protected:
    QList<QVariantMap> fetchRows() override;

private:
    double m_total = 0;
};
