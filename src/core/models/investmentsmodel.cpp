// SPDX-License-Identifier: MIT
#include "investmentsmodel.h"

#include "database.h"
#include "money.h"

#include <KLocalizedString>

#include <QSqlQuery>

using namespace Qt::StringLiterals;

namespace
{
QString typeLabel(const QString &type)
{
    if (type == "FIXED_INCOME"_L1) {
        return i18n("Fixed income");
    }
    if (type == "SECURITY"_L1) {
        return i18n("Securities");
    }
    if (type == "MUTUAL_FUND"_L1) {
        return i18n("Funds");
    }
    if (type == "EQUITY"_L1) {
        return i18n("Stocks");
    }
    if (type == "ETF"_L1) {
        return i18n("ETFs");
    }
    if (type == "COE"_L1) {
        return i18n("Structured notes (COE)");
    }
    return i18nc("investment type", "Other");
}
}

InvestmentsModel::InvestmentsModel(QObject *parent)
    : RowListModel({"investmentId", "name", "code", "type", "typeLabel", "subtype", "balance", "amount", "profit", "currency",
                    "lastTwelveMonthsRate", "dueDate", "dueLabel", "institution"},
                   parent)
{
}

double InvestmentsModel::total() const
{
    return m_total;
}

QList<QVariantMap> InvestmentsModel::fetchRows()
{
    QSqlQuery q(Database::connection());
    q.exec(u"SELECT id, name, code, type, subtype, balance, amount, amount_profit, currency, last_twelve_months_rate, due_date, institution"
           " FROM investments WHERE COALESCE(status, '') <> 'TOTAL_WITHDRAWAL'"
           " ORDER BY type, balance DESC"_s);
    QList<QVariantMap> rows;
    m_total = 0;
    while (q.next()) {
        const QDate due = QDate::fromString(q.value(10).toString(), Qt::ISODate);
        const double balance = q.value(5).toDouble();
        m_total += balance;
        rows.append(QVariantMap{
            {u"investmentId"_s, q.value(0)},
            {u"name"_s, q.value(1)},
            {u"code"_s, q.value(2)},
            {u"type"_s, q.value(3)},
            {u"typeLabel"_s, typeLabel(q.value(3).toString())},
            {u"subtype"_s, q.value(4)},
            {u"balance"_s, balance},
            {u"amount"_s, q.value(6).toDouble()},
            {u"profit"_s, q.value(7).toDouble()},
            {u"currency"_s, q.value(8)},
            {u"lastTwelveMonthsRate"_s, q.value(9).toDouble()},
            {u"dueDate"_s, due},
            {u"dueLabel"_s, MoneyFormat::shortDate(due)},
            {u"institution"_s, q.value(11)},
        });
    }
    return rows;
}
