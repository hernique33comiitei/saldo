// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QAbstractListModel>
#include <QQmlEngine>
#include <QVariantMap>

// Base for the read-only list models: rows are QVariantMaps loaded from the
// SQLite cache, roles are their keys. Reloads (coalesced) whenever the cache
// changes or a filter property changes.
class SALDOCORE_EXPORT RowListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit RowListModel(const QList<QByteArray> &roles, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE void reload();

Q_SIGNALS:
    void countChanged();
    // Summary properties of subclasses (totals, max values) changed. Emitted
    // BEFORE the rows are swapped, so charts bound to both see consistent
    // values (KQuickCharts keeps the range it had when the data arrived).
    void summaryChanged();
    void reloaded();

protected:
    virtual QList<QVariantMap> fetchRows();
    void scheduleReload();
    void appendRows(const QList<QVariantMap> &rows);

private:
    QList<QByteArray> m_roles;
    QList<QVariantMap> m_rows;
    bool m_reloadPending = false;
};
