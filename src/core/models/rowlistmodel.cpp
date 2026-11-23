// SPDX-License-Identifier: MIT
#include "rowlistmodel.h"

#include "database.h"

#include <QTimer>

RowListModel::RowListModel(const QList<QByteArray> &roles, QObject *parent)
    : QAbstractListModel(parent)
    , m_roles(roles)
{
    connect(Database::instance(), &Database::dataChanged, this, &RowListModel::scheduleReload);
    // Deferred so QML has set the filter properties before the first query.
    scheduleReload();
}

int RowListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_rows.size());
}

QVariant RowListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size()) {
        return {};
    }
    const int roleIndex = role - Qt::UserRole - 1;
    if (roleIndex < 0 || roleIndex >= m_roles.size()) {
        return {};
    }
    return m_rows.at(index.row()).value(QString::fromLatin1(m_roles.at(roleIndex)));
}

QHash<int, QByteArray> RowListModel::roleNames() const
{
    QHash<int, QByteArray> names;
    for (int i = 0; i < m_roles.size(); ++i) {
        names.insert(Qt::UserRole + 1 + i, m_roles.at(i));
    }
    return names;
}

int RowListModel::count() const
{
    return int(m_rows.size());
}

QVariantMap RowListModel::get(int row) const
{
    return row >= 0 && row < m_rows.size() ? m_rows.at(row) : QVariantMap();
}

void RowListModel::scheduleReload()
{
    if (m_reloadPending) {
        return;
    }
    m_reloadPending = true;
    QTimer::singleShot(0, this, &RowListModel::reload);
}

void RowListModel::reload()
{
    m_reloadPending = false;
    const int oldCount = count();
    QList<QVariantMap> rows = fetchRows(); // also updates subclass totals
    Q_EMIT summaryChanged();
    beginResetModel();
    m_rows = std::move(rows);
    endResetModel();
    if (oldCount != count()) {
        Q_EMIT countChanged();
    }
    Q_EMIT reloaded();
}

QList<QVariantMap> RowListModel::fetchRows()
{
    return {};
}

void RowListModel::appendRows(const QList<QVariantMap> &rows)
{
    if (rows.isEmpty()) {
        return;
    }
    beginInsertRows({}, int(m_rows.size()), int(m_rows.size() + rows.size() - 1));
    m_rows.append(rows);
    endInsertRows();
    Q_EMIT countChanged();
}
