// SPDX-License-Identifier: MIT
#include "cardbills.h"

#include "database.h"

#include <QSqlQuery>

#include <algorithm>

using namespace Qt::StringLiterals;

namespace
{
// Moves a past date forward month by month until it is not before `floor`.
QDate rollForward(QDate date, const QDate &floor)
{
    if (!date.isValid()) {
        return date;
    }
    for (int i = 0; i < 24 && date < floor; ++i) {
        date = date.addMonths(1);
    }
    return date;
}

double sumSpent(const QString &where, const QVariantList &values)
{
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT COALESCE(-SUM(t.normalized_amount), 0) FROM transactions t WHERE "_s + where);
    for (const QVariant &value : values) {
        q.addBindValue(value);
    }
    return q.exec() && q.next() ? q.value(0).toDouble() : 0.0;
}
}

CardBill computeCardBill(const QString &accountId, const QDate &creditCloseDate, const QDate &creditDueDate)
{
    CardBill bill;
    const QDate today = QDate::currentDate();
    QSqlQuery q(Database::connection());

    q.prepare(u"SELECT closing_date, due_date, total_amount FROM bills WHERE account_id = ? ORDER BY due_date DESC LIMIT 1"_s);
    q.addBindValue(accountId);
    const bool hasBills = q.exec() && q.next();
    if (hasBills) {
        bill.lastDue = QDate::fromString(q.value(1).toString(), Qt::ISODate);
        bill.lastClosing = QDate::fromString(q.value(0).toString(), Qt::ISODate);
        if (!bill.lastClosing.isValid() && bill.lastDue.isValid()) {
            bill.lastClosing = bill.lastDue.addDays(-7);
        }
        bill.lastTotal = q.value(2).toDouble();
    } else {
        bill.lastClosing = creditCloseDate;
        bill.lastDue = creditDueDate;
    }

    q.prepare(u"SELECT 1 FROM transactions WHERE account_id = ? AND COALESCE(bill_id, '') <> '' LIMIT 1"_s);
    q.addBindValue(accountId);
    const bool usesBillIds = q.exec() && q.next();

    if (hasBills || usesBillIds) {
        // Not on any bill yet = open bill. Payments are internal (excluded);
        // refunds count against it.
        bill.open = sumSpent(u"t.account_id = ? AND COALESCE(t.bill_id, '') = '' AND t.internal = 0"_s, {accountId});
        bill.known = true;
    } else if (creditCloseDate.isValid()) {
        bill.open = sumSpent(u"t.account_id = ? AND t.date > ? AND t.internal = 0"_s, {accountId, creditCloseDate.toString(Qt::ISODate)});
        bill.known = true;
    }

    bill.openClosing = rollForward(bill.lastClosing.isValid() ? bill.lastClosing.addMonths(1) : QDate(), today);
    bill.openDue = rollForward(bill.lastDue.isValid() ? bill.lastDue.addMonths(1) : QDate(), bill.openClosing.isValid() ? bill.openClosing : today);

    // Money paid into the card since the last bill closed (payments, and
    // refunds, which also lower what is owed) against that bill's total.
    if (hasBills && bill.lastTotal > 0.005) {
        q.prepare(u"SELECT COALESCE(SUM(normalized_amount), 0) FROM transactions WHERE account_id = ? AND normalized_amount > 0 AND date >= ?"_s);
        q.addBindValue(accountId);
        q.addBindValue(bill.lastClosing.isValid() ? bill.lastClosing.toString(Qt::ISODate) : bill.lastDue.addDays(-10).toString(Qt::ISODate));
        const double paid = q.exec() && q.next() ? q.value(0).toDouble() : 0.0;
        bill.lastUnpaid = bill.lastTotal - paid >= 0.01 ? bill.lastTotal - paid : 0.0;
        if (bill.lastDue.isValid() && bill.lastDue >= today) {
            bill.closedToPay = bill.lastUnpaid;
        }
    }
    bill.open = std::max(0.0, bill.open);
    return bill;
}
