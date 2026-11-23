// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// The configured Meu Pluggy connections (item IDs) and their last known state.
class SALDOCORE_EXPORT ItemsModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit ItemsModel(QObject *parent = nullptr);

protected:
    QList<QVariantMap> fetchRows() override;
};
