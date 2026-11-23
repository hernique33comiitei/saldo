// SPDX-License-Identifier: MIT
#include "categoryspendmodel.h"

#include "categories.h"
#include "database.h"

#include <KLocalizedString>

#include <QSqlQuery>

using namespace Qt::StringLiterals;

CategorySpendModel::CategorySpendModel(QObject *parent)
    : RowListModel({"name", "amount", "ratio", "iconName"}, parent)
{
}

QString CategorySpendModel::month() const
{
    return m_month;
}

void CategorySpendModel::setMonth(const QString &month)
{
    if (m_month != month) {
        m_month = month;
        Q_EMIT monthChanged();
        scheduleReload();
    }
}

int CategorySpendModel::maximumCategories() const
{
    return m_maximumCategories;
}

void CategorySpendModel::setMaximumCategories(int maximum)
{
    maximum = qMax(1, maximum);
    if (m_maximumCategories != maximum) {
        m_maximumCategories = maximum;
        Q_EMIT monthChanged();
        scheduleReload();
    }
}

double CategorySpendModel::total() const
{
    return m_total;
}

QList<QVariantMap> CategorySpendModel::fetchRows()
{
    const QString month = m_month.isEmpty() ? QDate::currentDate().toString(u"yyyy-MM"_s) : m_month;
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT t.category,"
              " (SELECT c.description_translated FROM categories c WHERE c.description = t.category LIMIT 1),"
              " SUM(-t.normalized_amount) AS spent"
              " FROM transactions t JOIN accounts a ON a.id = t.account_id"
              // Card refunds (money into a card) lower their category's total.
              " WHERE (t.normalized_amount < 0 OR a.type = 'CREDIT') AND substr(t.date, 1, 7) = ? AND "_s
              + Database::countedSql() + u" GROUP BY t.category HAVING spent > 0.005 ORDER BY spent DESC"_s);
    q.addBindValue(month);
    q.exec();

    struct Entry {
        QString name;
        QString icon;
        double amount;
    };
    QList<Entry> entries;
    m_total = 0;
    while (q.next()) {
        const QString category = q.value(0).toString();
        const double amount = q.value(2).toDouble();
        m_total += amount;
        entries.append({Categories::displayName(category, q.value(1).toString()), Categories::iconName(category), amount});
    }

    if (entries.size() > m_maximumCategories) {
        double rest = 0;
        for (qsizetype i = m_maximumCategories - 1; i < entries.size(); ++i) {
            rest += entries.at(i).amount;
        }
        entries.resize(m_maximumCategories - 1);
        entries.append({i18nc("all other expense categories", "Other"), u"tag-symbolic"_s, rest});
    }

    QList<QVariantMap> rows;
    for (const Entry &entry : std::as_const(entries)) {
        rows.append(QVariantMap{
            {u"name"_s, entry.name},
            {u"amount"_s, entry.amount},
            {u"ratio"_s, m_total > 0 ? entry.amount / m_total : 0.0},
            {u"iconName"_s, entry.icon},
        });
    }
    return rows;
}
