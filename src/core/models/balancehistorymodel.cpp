// SPDX-License-Identifier: MIT
#include "balancehistorymodel.h"

#include "database.h"
#include "money.h"

#include <QSqlQuery>

using namespace Qt::StringLiterals;

BalanceHistoryModel::BalanceHistoryModel(QObject *parent)
    : RowListModel({"day", "label", "total"}, parent)
{
}

int BalanceHistoryModel::days() const
{
    return m_days;
}

void BalanceHistoryModel::setDays(int days)
{
    days = qBound(7, days, 730);
    if (m_days != days) {
        m_days = days;
        Q_EMIT daysChanged();
        scheduleReload();
    }
}

double BalanceHistoryModel::minValue() const
{
    return m_minValue;
}

double BalanceHistoryModel::maxValue() const
{
    return m_maxValue;
}

QDate BalanceHistoryModel::firstDay() const
{
    return m_firstDay;
}

QDate BalanceHistoryModel::lastDay() const
{
    return m_lastDay;
}

double BalanceHistoryModel::firstValue() const
{
    return m_firstValue;
}

double BalanceHistoryModel::lastValue() const
{
    return m_lastValue;
}

QList<QVariantMap> BalanceHistoryModel::fetchRows()
{
    const QDate today = QDate::currentDate();
    const QDate first = today.addDays(-(m_days - 1));
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT s.day, SUM(s.balance) FROM balance_snapshots s"
              " JOIN accounts a ON a.id = s.account_id AND a.type = 'BANK'"
              " WHERE s.day >= ? GROUP BY s.day ORDER BY s.day"_s);
    q.addBindValue(first.toString(Qt::ISODate));
    q.exec();

    QList<QVariantMap> rows;
    m_minValue = 0;
    m_maxValue = 0;
    m_firstDay = QDate();
    m_lastDay = QDate();
    m_firstValue = 0;
    m_lastValue = 0;
    auto append = [&](const QDate &day, double total) {
        if (rows.isEmpty()) {
            m_minValue = m_maxValue = total;
            m_firstDay = day;
            m_firstValue = total;
        }
        m_lastDay = day;
        m_lastValue = total;
        m_minValue = std::min(m_minValue, total);
        m_maxValue = std::max(m_maxValue, total);
        rows.append(QVariantMap{{u"day"_s, day}, {u"label"_s, MoneyFormat::shortDate(day)}, {u"total"_s, total}});
    };
    QDate last;
    while (q.next()) {
        last = QDate::fromString(q.value(0).toString(), Qt::ISODate);
        append(last, q.value(1).toDouble());
    }

    // Today's live balance, if no snapshot was taken yet today.
    if (last != today) {
        q.exec(u"SELECT SUM(balance), COUNT(*) FROM accounts WHERE type = 'BANK'"_s);
        if (q.next() && q.value(1).toInt() > 0) {
            append(today, q.value(0).toDouble());
        }
    }
    return rows;
}
