// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// Bank accounts and credit cards. `type` filters: "" (all), "BANK", "CREDIT".
class SALDOCORE_EXPORT AccountsModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString type READ type WRITE setType NOTIFY typeChanged)
    Q_PROPERTY(double total READ total NOTIFY summaryChanged)

public:
    explicit AccountsModel(QObject *parent = nullptr);

    QString type() const;
    void setType(const QString &type);
    double total() const;

Q_SIGNALS:
    void typeChanged();

protected:
    QList<QVariantMap> fetchRows() override;

private:
    QString m_type;
    double m_total = 0;
};
