// SPDX-License-Identifier: MIT
#include "transactionsmodel.h"

#include "categories.h"
#include "database.h"
#include "money.h"

#include <KLocalizedString>

#include <QSqlQuery>

using namespace Qt::StringLiterals;

namespace
{
constexpr int PageSize = 100;
}

TransactionsModel::TransactionsModel(QObject *parent)
    : RowListModel({"transactionId", "date", "dateLabel", "description", "amount", "currency", "category", "categoryLabel",
                    "categoryIcon", "accountName", "accountType", "pending", "installment", "merchant", "counterparty",
                    "internal", "internalReason", "internalManual", "matchAccount"},
                   parent)
{
    connect(this, &TransactionsModel::filterChanged, this, &TransactionsModel::scheduleReload);
}

QString TransactionsModel::accountId() const
{
    return m_accountId;
}

void TransactionsModel::setAccountId(const QString &id)
{
    if (m_accountId != id) {
        m_accountId = id;
        Q_EMIT filterChanged();
    }
}

QString TransactionsModel::searchText() const
{
    return m_searchText;
}

void TransactionsModel::setSearchText(const QString &text)
{
    if (m_searchText != text) {
        m_searchText = text;
        Q_EMIT filterChanged();
    }
}

QString TransactionsModel::month() const
{
    return m_month;
}

void TransactionsModel::setMonth(const QString &month)
{
    if (m_month != month) {
        m_month = month;
        Q_EMIT filterChanged();
    }
}

TransactionsModel::Kind TransactionsModel::kind() const
{
    return m_kind;
}

void TransactionsModel::setKind(Kind kind)
{
    if (m_kind != kind) {
        m_kind = kind;
        Q_EMIT filterChanged();
    }
}

int TransactionsModel::limit() const
{
    return m_limit;
}

void TransactionsModel::setLimit(int limit)
{
    if (m_limit != limit) {
        m_limit = limit;
        Q_EMIT filterChanged();
    }
}

bool TransactionsModel::canLoadMore() const
{
    return m_canLoadMore;
}

double TransactionsModel::totalIncome() const
{
    return m_totalIncome;
}

double TransactionsModel::totalExpense() const
{
    return m_totalExpense;
}

namespace
{
struct Filter {
    QString where;
    QVariantList values;
};

Filter buildFilter(const QString &accountId, const QString &search, const QString &month, TransactionsModel::Kind kind)
{
    QStringList clauses{u"1 = 1"_s};
    QVariantList values;
    if (!accountId.isEmpty()) {
        clauses << u"t.account_id = ?"_s;
        values << accountId;
    }
    if (!search.trimmed().isEmpty()) {
        const QString like = u"%"_s + search.trimmed() + u"%"_s;
        clauses << u"(t.description LIKE ? OR t.merchant LIKE ? OR t.category LIKE ?)"_s;
        values << like << like << like;
    }
    if (!month.isEmpty()) {
        clauses << u"substr(t.date, 1, 7) = ?"_s;
        values << month;
    }
    if (kind == TransactionsModel::Income) {
        clauses << u"t.normalized_amount > 0"_s;
    } else if (kind == TransactionsModel::Expense) {
        clauses << u"t.normalized_amount < 0"_s;
    }
    return {clauses.join(u" AND "_s), values};
}
}

namespace
{
// Why a transaction is (or is not) treated as a movement between own accounts.
QString internalReasonText(const QString &reason, const QString &matchAccount)
{
    if (reason == "category"_L1) {
        return i18n("Pluggy classifies it as a transfer between your own accounts or a card bill payment.");
    }
    if (reason == "document"_L1) {
        return i18n("Sent to or received from your own CPF/CNPJ.");
    }
    if (reason == "pair"_L1) {
        return matchAccount.isEmpty() ? i18n("The same amount moved between two of your accounts.")
                                      : i18n("The same amount moved to or from %1.", matchAccount);
    }
    if (reason == "card-payment"_L1) {
        return matchAccount.isEmpty() ? i18n("Credit card bill paid from one of your accounts.")
                                      : i18n("Credit card bill payment, matched with %1.", matchAccount);
    }
    if (reason == "manual"_L1) {
        return i18n("You marked it as a transfer between your accounts.");
    }
    if (reason == "manual-counted"_L1) {
        return i18n("You marked it to count as income or expense.");
    }
    return QString();
}
}

void TransactionsModel::setInternal(const QString &transactionId, int value)
{
    if (Database::setInternalOverride(transactionId, value)) {
        Database::instance()->notifyChanged();
    }
}

QList<QVariantMap> TransactionsModel::query(int limit, int offset)
{
    const Filter filter = buildFilter(m_accountId, m_searchText, m_month, m_kind);
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT t.id, t.date, t.description, t.normalized_amount, t.currency, t.category,"
              " (SELECT c.description_translated FROM categories c WHERE c.description = t.category LIMIT 1),"
              " t.status, t.installment_number, t.total_installments, t.merchant, a.name, a.marketing_name, a.type,"
              " t.counterparty_name, t.internal, COALESCE(t.internal_reason, ''),"
              " (SELECT COALESCE(NULLIF(a2.marketing_name, ''), a2.name) FROM transactions t2"
              "  JOIN accounts a2 ON a2.id = t2.account_id WHERE t2.id = t.internal_match)"
              " FROM transactions t LEFT JOIN accounts a ON a.id = t.account_id"
              " WHERE "_s
              + filter.where + u" ORDER BY t.date DESC, t.rowid DESC LIMIT ? OFFSET ?"_s);
    for (const QVariant &value : filter.values) {
        q.addBindValue(value);
    }
    q.addBindValue(limit);
    q.addBindValue(offset);
    q.exec();

    QList<QVariantMap> rows;
    while (q.next()) {
        const QDate date = QDate::fromString(q.value(1).toString(), Qt::ISODate);
        const QString category = q.value(5).toString();
        const int installment = q.value(8).toInt();
        const int installments = q.value(9).toInt();
        const QString accountName = q.value(12).toString().isEmpty() ? q.value(11).toString() : q.value(12).toString();
        rows.append(QVariantMap{
            {u"transactionId"_s, q.value(0)},
            {u"date"_s, date},
            {u"dateLabel"_s, MoneyFormat::dayLabel(date)},
            {u"description"_s, q.value(2)},
            {u"amount"_s, q.value(3).toDouble()},
            {u"currency"_s, q.value(4)},
            {u"category"_s, category},
            {u"categoryLabel"_s, Categories::displayName(category, q.value(6).toString())},
            {u"categoryIcon"_s, Categories::iconName(category)},
            {u"pending"_s, q.value(7).toString() == "PENDING"_L1},
            {u"installment"_s, installments > 1 ? i18nc("installment number of total", "%1/%2", installment, installments) : QString()},
            {u"merchant"_s, q.value(10)},
            {u"accountName"_s, accountName},
            {u"accountType"_s, q.value(13)},
            {u"counterparty"_s, q.value(14)},
            {u"internal"_s, q.value(15).toInt() == 1},
            {u"internalReason"_s, internalReasonText(q.value(16).toString(), q.value(17).toString())},
            {u"internalManual"_s, q.value(16).toString().startsWith("manual"_L1)},
            {u"matchAccount"_s, q.value(17)},
        });
    }
    return rows;
}

void TransactionsModel::computeTotals()
{
    const Filter filter = buildFilter(m_accountId, m_searchText, m_month, m_kind);
    QSqlQuery q(Database::connection());
    q.prepare(u"SELECT "_s + Database::incomeSql() + u", "_s + Database::expenseSql()
              + u" FROM transactions t JOIN accounts a ON a.id = t.account_id WHERE "_s + filter.where + u" AND "_s
              + Database::countedSql());
    for (const QVariant &value : filter.values) {
        q.addBindValue(value);
    }
    q.exec();
    m_totalIncome = 0;
    m_totalExpense = 0;
    if (q.next()) {
        m_totalIncome = q.value(0).toDouble();
        m_totalExpense = q.value(1).toDouble();
    }
}

QList<QVariantMap> TransactionsModel::fetchRows()
{
    const int pageSize = m_limit > 0 ? m_limit : PageSize;
    QList<QVariantMap> rows = query(pageSize, 0);
    m_loaded = int(rows.size());
    m_canLoadMore = m_limit <= 0 && rows.size() == pageSize;
    computeTotals();
    return rows;
}

void TransactionsModel::loadMore()
{
    if (!m_canLoadMore) {
        return;
    }
    const QList<QVariantMap> rows = query(PageSize, m_loaded);
    m_loaded += int(rows.size());
    m_canLoadMore = rows.size() == PageSize;
    Q_EMIT summaryChanged();
    appendRows(rows);
    Q_EMIT reloaded();
}
