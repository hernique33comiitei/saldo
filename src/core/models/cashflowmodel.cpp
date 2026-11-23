// SPDX-License-Identifier: MIT
#include "cashflowmodel.h"

#include "categories.h"
#include "database.h"
#include "money.h"

#include <QSqlQuery>

using namespace Qt::StringLiterals;

CashflowModel::CashflowModel(QObject *parent)
    : RowListModel({"month", "label", "monthLabel", "income", "expense", "net"}, parent)
{
}

int CashflowModel::months() const
{
    return m_months;
}

void CashflowModel::setMonths(int months)
{
    months = qBound(1, months, 24);
    if (m_months != months) {
        m_months = months;
        Q_EMIT monthsChanged();
        scheduleReload();
    }
}

QString CashflowModel::endMonth() const
{
    return m_endMonth;
}

void CashflowModel::setEndMonth(const QString &month)
{
    if (m_endMonth != month) {
        m_endMonth = month;
        Q_EMIT monthsChanged();
        scheduleReload();
    }
}

double CashflowModel::maxValue() const
{
    return m_maxValue;
}

double CashflowModel::endIncome() const
{
    return m_endIncome;
}

double CashflowModel::endExpense() const
{
    return m_endExpense;
}

QList<QVariantMap> CashflowModel::fetchRows()
{
    QDate thisMonth = QDate::fromString(m_endMonth + u"-01"_s, Qt::ISODate);
    if (!thisMonth.isValid()) {
        thisMonth = QDate(QDate::currentDate().year(), QDate::currentDate().month(), 1);
    }
    const QDate first = thisMonth.addMonths(-(m_months - 1));

    QHash<QString, std::pair<double, double>> sums;
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT substr(t.date, 1, 7) AS month, "_s + Database::incomeSql() + u", "_s + Database::expenseSql()
              + u" FROM transactions t JOIN accounts a ON a.id = t.account_id WHERE t.date >= ? AND t.date < ? AND "_s
              + Database::countedSql() + u" GROUP BY month"_s);
    q.addBindValue(first.toString(Qt::ISODate));
    q.addBindValue(thisMonth.addMonths(1).toString(Qt::ISODate));
    q.exec();
    while (q.next()) {
        sums.insert(q.value(0).toString(), {q.value(1).toDouble(), q.value(2).toDouble()});
    }

    QList<QVariantMap> rows;
    m_maxValue = 0;
    for (QDate month = first; month <= thisMonth; month = month.addMonths(1)) {
        const QString key = month.toString(u"yyyy-MM"_s);
        const auto [income, expense] = sums.value(key, {0.0, 0.0});
        m_maxValue = std::max({m_maxValue, income, expense});
        m_endIncome = income;
        m_endExpense = expense;
        rows.append(QVariantMap{
            {u"month"_s, key},
            {u"label"_s, MoneyFormat::shortMonthLabel(month)},
            {u"monthLabel"_s, MoneyFormat::monthLabel(month)},
            {u"income"_s, income},
            {u"expense"_s, expense},
            {u"net"_s, income - expense},
        });
    }
    return rows;
}
