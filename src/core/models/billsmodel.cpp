// SPDX-License-Identifier: MIT
#include "billsmodel.h"

#include "database.h"
#include "money.h"

#include <QSqlQuery>

using namespace Qt::StringLiterals;

BillsModel::BillsModel(QObject *parent)
    : RowListModel({"billId", "dueDate", "dueLabel", "closingLabel", "monthLabel", "totalAmount", "minimumPayment", "currency"}, parent)
{
}

QString BillsModel::accountId() const
{
    return m_accountId;
}

void BillsModel::setAccountId(const QString &id)
{
    if (m_accountId != id) {
        m_accountId = id;
        Q_EMIT accountIdChanged();
        scheduleReload();
    }
}

double BillsModel::maxValue() const
{
    return m_maxValue;
}

QList<QVariantMap> BillsModel::fetchRows()
{
    QList<QVariantMap> rows;
    m_maxValue = 0;
    if (m_accountId.isEmpty()) {
        return rows;
    }
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT id, due_date, closing_date, total_amount, minimum_payment, currency FROM bills WHERE account_id = ? ORDER BY due_date DESC LIMIT 24"_s);
    q.addBindValue(m_accountId);
    q.exec();
    while (q.next()) {
        const QDate due = QDate::fromString(q.value(1).toString(), Qt::ISODate);
        const QDate closing = QDate::fromString(q.value(2).toString(), Qt::ISODate);
        const double total = q.value(3).toDouble();
        m_maxValue = std::max(m_maxValue, total);
        rows.append(QVariantMap{
            {u"billId"_s, q.value(0)},
            {u"dueDate"_s, due},
            {u"dueLabel"_s, MoneyFormat::shortDate(due)},
            {u"closingLabel"_s, MoneyFormat::shortDate(closing)},
            {u"monthLabel"_s, due.isValid() ? MoneyFormat::monthLabel(due) : QString()},
            {u"totalAmount"_s, total},
            {u"minimumPayment"_s, q.value(4).toDouble()},
            {u"currency"_s, q.value(5)},
        });
    }
    return rows;
}
