// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// Closed credit card bills of one card, newest first.
class SALDOCORE_EXPORT BillsModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString accountId READ accountId WRITE setAccountId NOTIFY accountIdChanged)
    Q_PROPERTY(double maxValue READ maxValue NOTIFY summaryChanged)

public:
    explicit BillsModel(QObject *parent = nullptr);

    QString accountId() const;
    void setAccountId(const QString &id);
    double maxValue() const;

Q_SIGNALS:
    void accountIdChanged();

protected:
    QList<QVariantMap> fetchRows() override;

private:
    QString m_accountId;
    double m_maxValue = 0;
};
