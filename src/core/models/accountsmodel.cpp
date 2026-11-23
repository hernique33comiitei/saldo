// SPDX-License-Identifier: MIT
#include "accountsmodel.h"

#include "cardbills.h"
#include "cardtotals.h"
#include "config.h"
#include "database.h"
#include "money.h"

#include <KLocalizedString>

#include <QSqlQuery>

#include <algorithm>

using namespace Qt::StringLiterals;

namespace
{
QString subtypeLabel(const QString &subtype)
{
    if (subtype == "CHECKING_ACCOUNT"_L1) {
        return i18n("Checking account");
    }
    if (subtype == "SAVINGS_ACCOUNT"_L1) {
        return i18n("Savings account");
    }
    if (subtype == "CREDIT_CARD"_L1) {
        return i18n("Credit card");
    }
    return subtype;
}

QString iconFor(const QString &type, const QString &subtype)
{
    if (type == "CREDIT"_L1) {
        return u"view-financial-account-credit-card"_s;
    }
    if (subtype == "SAVINGS_ACCOUNT"_L1) {
        return u"view-financial-account-savings"_s;
    }
    return u"view-financial-account-checking"_s;
}

QString capitalized(QString text)
{
    text = text.toLower();
    if (!text.isEmpty()) {
        text[0] = text[0].toUpper();
    }
    return text;
}
}

AccountsModel::AccountsModel(QObject *parent)
    : RowListModel({"accountId", "itemId", "name", "institution", "type", "subtype", "subtypeLabel", "number", "numberLabel",
                    "owner", "balance", "currency", "creditLimit", "availableCreditLimit", "usedCredit", "usedRatio",
                    "minimumPayment", "cardLabel", "holderType",
                    "included", "sharedLimit", "iconName", "raw", "billKnown", "currentBill", "currentBillCloseLabel",
                    "currentBillDueLabel", "closedToPay", "lastBillTotal", "lastBillDueLabel", "lastBillPaid", "lastBillOverdue"},
                   parent)
{
    connect(Config::instance(), &Config::excludedCardIdsChanged, this, &AccountsModel::scheduleReload);
    connect(Config::instance(), &Config::itemNamesChanged, this, &AccountsModel::scheduleReload);
}

QString AccountsModel::type() const
{
    return m_type;
}

void AccountsModel::setType(const QString &type)
{
    if (m_type != type) {
        m_type = type;
        Q_EMIT typeChanged();
        scheduleReload();
    }
}

double AccountsModel::total() const
{
    return m_total;
}

QList<QVariantMap> AccountsModel::fetchRows()
{
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT a.id, a.item_id, a.name, a.marketing_name, i.connector_name, a.type, a.subtype, a.number, a.owner,"
              " a.balance, a.currency, a.credit_limit, a.available_credit_limit, a.close_date, a.due_date, a.minimum_payment,"
              " a.brand, a.level, a.holder_type, a.raw"
              " FROM accounts a LEFT JOIN items i ON i.id = a.item_id"
              " WHERE (COALESCE(?, '') = '' OR a.type = ?)"
              " ORDER BY a.type DESC, i.connector_name, a.name"_s);
    q.addBindValue(m_type);
    q.addBindValue(m_type);
    q.exec();

    QList<QVariantMap> rows;
    QList<CardLimitRow> cards;
    while (q.next()) {
        const QString id = q.value(0).toString();
        const QString name = q.value(3).toString().isEmpty() ? q.value(2).toString() : q.value(3).toString();
        const QString type = q.value(5).toString();
        const QString subtype = q.value(6).toString();
        const QString number = q.value(7).toString();
        const double limit = q.value(11).toDouble();
        const double available = q.value(12).toDouble();
        const double used = qMax(0.0, limit - available);
        const QDate closeDate = QDate::fromString(q.value(13).toString(), Qt::ISODate);
        const QDate dueDate = QDate::fromString(q.value(14).toString(), Qt::ISODate);
        const QString brand = q.value(16).toString();
        const QString level = q.value(17).toString();

        QString numberLabel;
        if (!number.isEmpty()) {
            numberLabel = type == "CREDIT"_L1 ? u"•••• "_s + number.right(4) : number;
        }
        QStringList cardParts;
        if (!brand.isEmpty()) {
            cardParts << capitalized(brand);
        }
        if (!level.isEmpty()) {
            cardParts << capitalized(level);
        }

        rows.append(QVariantMap{
            {u"accountId"_s, id},
            {u"itemId"_s, q.value(1)},
            {u"name"_s, name},
            {u"institution"_s, Config::instance()->displayItemName(q.value(1).toString(), q.value(4).toString())},
            {u"type"_s, type},
            {u"subtype"_s, subtype},
            {u"subtypeLabel"_s, subtypeLabel(subtype)},
            {u"number"_s, number},
            {u"numberLabel"_s, numberLabel},
            {u"owner"_s, q.value(8)},
            {u"balance"_s, q.value(9).toDouble()},
            {u"currency"_s, q.value(10)},
            {u"creditLimit"_s, limit},
            {u"availableCreditLimit"_s, available},
            {u"usedCredit"_s, used},
            {u"usedRatio"_s, limit > 0 ? used / limit : 0.0},
            {u"minimumPayment"_s, q.value(15).toDouble()},
            {u"cardLabel"_s, cardParts.join(u' ')},
            {u"holderType"_s, q.value(18)},
            {u"iconName"_s, iconFor(type, subtype)},
            {u"raw"_s, q.value(19)},
        });
        if (type == "CREDIT"_L1) {
            const CardBill bill = computeCardBill(id, closeDate, dueDate);
            QVariantMap &row = rows.last();
            row.insert(u"billKnown"_s, bill.known);
            row.insert(u"currentBill"_s, bill.open);
            row.insert(u"currentBillCloseLabel"_s, MoneyFormat::shortDate(bill.openClosing));
            row.insert(u"currentBillDueLabel"_s, MoneyFormat::shortDate(bill.openDue));
            row.insert(u"closedToPay"_s, bill.closedToPay);
            row.insert(u"lastBillTotal"_s, bill.lastTotal);
            row.insert(u"lastBillDueLabel"_s, MoneyFormat::shortDate(bill.lastDue));
            row.insert(u"lastBillPaid"_s, bill.lastPaid());
            row.insert(u"lastBillOverdue"_s, bill.lastOverdue());
            cards.append({id, q.value(1).toString(), q.value(18).toString(), limit, available});
        }
    }

    std::stable_sort(rows.begin(), rows.end(), [](const QVariantMap &a, const QVariantMap &b) {
        const QString typeA = a.value(u"type"_s).toString();
        const QString typeB = b.value(u"type"_s).toString();
        if (typeA != typeB) {
            return typeA > typeB; // CREDIT after BANK
        }
        return QString::localeAwareCompare(a.value(u"institution"_s).toString(), b.value(u"institution"_s).toString()) < 0;
    });

    const QStringList excluded = Config::instance()->excludedCardIds();
    const CardTotals totals = computeCardTotals(cards, excluded);
    m_total = 0;
    for (QVariantMap &row : rows) {
        const QString id = row.value(u"accountId"_s).toString();
        const bool isCard = row.value(u"type"_s).toString() == "CREDIT"_L1;
        row.insert(u"included"_s, !isCard || !excluded.contains(id));
        row.insert(u"sharedLimit"_s, totals.shared.contains(id));
        if (!isCard) {
            m_total += row.value(u"balance"_s).toDouble();
        } else if (totals.counted.contains(id)) {
            m_total += row.value(u"balance"_s).toDouble();
        }
    }
    return rows;
}
