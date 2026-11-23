// SPDX-License-Identifier: MIT
#include "database.h"

#include "demodata.h"
#include "logging.h"
#include "paths.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QThread>

#include <cmath>
#include <functional>
#include <limits>

using namespace Qt::StringLiterals;

namespace
{
constexpr int SchemaVersion = 2;

const char *const SchemaStatements[] = {
    "CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)",
    "CREATE TABLE IF NOT EXISTS items ("
    " id TEXT PRIMARY KEY, connector_name TEXT, connector_image TEXT, status TEXT, execution_status TEXT,"
    " error_code TEXT, error_message TEXT, last_updated_at TEXT, consent_expires_at TEXT, next_auto_sync_at TEXT,"
    " raw TEXT)",
    "CREATE TABLE IF NOT EXISTS accounts ("
    " id TEXT PRIMARY KEY, item_id TEXT NOT NULL, type TEXT, subtype TEXT, name TEXT, marketing_name TEXT,"
    " number TEXT, owner TEXT, currency TEXT, balance REAL, has_credit INTEGER, credit_limit REAL,"
    " available_credit_limit REAL, minimum_payment REAL, close_date TEXT, due_date TEXT, brand TEXT, level TEXT,"
    " holder_type TEXT, credit_status TEXT, tax_number TEXT, raw TEXT)",
    "CREATE TABLE IF NOT EXISTS transactions ("
    " id TEXT PRIMARY KEY, account_id TEXT NOT NULL, date TEXT, description TEXT, amount REAL, normalized_amount REAL,"
    " currency TEXT, category TEXT, category_id TEXT, type TEXT, status TEXT, merchant TEXT,"
    " installment_number INTEGER, total_installments INTEGER, bill_id TEXT, counterparty_name TEXT,"
    " counterparty_document TEXT, internal INTEGER NOT NULL DEFAULT 0, internal_reason TEXT, internal_match TEXT)",
    "CREATE INDEX IF NOT EXISTS transactions_account_date ON transactions (account_id, date)",
    "CREATE INDEX IF NOT EXISTS transactions_date ON transactions (date)",
    "CREATE TABLE IF NOT EXISTS bills ("
    " id TEXT PRIMARY KEY, account_id TEXT NOT NULL, due_date TEXT, closing_date TEXT, total_amount REAL,"
    " minimum_payment REAL, currency TEXT, raw TEXT)",
    "CREATE TABLE IF NOT EXISTS investments ("
    " id TEXT PRIMARY KEY, item_id TEXT NOT NULL, name TEXT, code TEXT, type TEXT, subtype TEXT, currency TEXT,"
    " status TEXT, institution TEXT, balance REAL, amount REAL, amount_profit REAL, annual_rate REAL,"
    " last_month_rate REAL, last_twelve_months_rate REAL, date TEXT, due_date TEXT, raw TEXT)",
    "CREATE TABLE IF NOT EXISTS categories ("
    " id TEXT PRIMARY KEY, description TEXT, description_translated TEXT, parent_id TEXT, parent_description TEXT)",
    // User data, kept across cache rebuilds (see Tables):
    "CREATE TABLE IF NOT EXISTS transaction_overrides (id TEXT PRIMARY KEY, internal INTEGER NOT NULL)",
    "CREATE TABLE IF NOT EXISTS balance_snapshots ("
    " day TEXT NOT NULL, account_id TEXT NOT NULL, balance REAL, PRIMARY KEY (day, account_id))",
};

// Cache tables: dropped on schema changes and cleared by clearAll(). The user's
// own data (transaction_overrides, balance_snapshots) is never in this list.
const char *const Tables[] = {"items", "accounts", "transactions", "bills", "investments", "categories", "meta"};

QString connectionName()
{
    return u"saldo-%1"_s.arg(quintptr(QThread::currentThread()), 0, 16);
}

bool exec(QSqlQuery &query)
{
    if (!query.exec()) {
        qCWarning(SALDO_LOG) << "SQL error:" << query.lastError().text() << query.lastQuery();
        return false;
    }
    return true;
}

bool execText(QSqlDatabase db, const QString &sql)
{
    QSqlQuery query(db);
    if (!query.exec(sql)) {
        qCWarning(SALDO_LOG) << "SQL error:" << query.lastError().text() << sql;
        return false;
    }
    return true;
}

QVariant dateValue(const QDate &date)
{
    return date.isValid() ? QVariant(date.toString(Qt::ISODate)) : QVariant();
}

QVariant dateTimeValue(const QDateTime &dt)
{
    return dt.isValid() ? QVariant(dt.toUTC().toString(Qt::ISODateWithMs)) : QVariant();
}

// Columns added by later schema versions. A table missing one of them is from
// an older Saldo even if user_version says otherwise (the version stamp alone
// once lied after a concurrent rebuild by an old plasmashell). Add the newest
// column of each changed table here when bumping SchemaVersion.
const std::pair<const char *, const char *> SentinelColumns[] = {
    {"accounts", "tax_number"},
    {"transactions", "internal"},
};

bool tableExists(QSqlDatabase db, const QString &table)
{
    QSqlQuery q(db);
    q.prepare(u"SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?"_s);
    q.addBindValue(table);
    return q.exec() && q.next();
}

bool hasColumn(QSqlDatabase db, const QString &table, const QString &column)
{
    QSqlQuery q(db);
    if (!q.exec(u"PRAGMA table_info(%1)"_s.arg(table))) {
        return false;
    }
    while (q.next()) {
        if (q.value(1).toString() == column) {
            return true;
        }
    }
    return false;
}

void ensureSchema(QSqlDatabase db)
{
    execText(db, u"PRAGMA journal_mode=WAL"_s);
    execText(db, u"PRAGMA synchronous=NORMAL"_s);
    execText(db, u"PRAGMA busy_timeout=5000"_s);

    // Take the write lock before looking: the app and the widget may open the
    // file at the same moment, and their checks/rebuilds must not interleave.
    execText(db, u"BEGIN IMMEDIATE"_s);

    QSqlQuery version(db);
    version.exec(u"PRAGMA user_version"_s);
    const int current = version.next() ? version.value(0).toInt() : 0;
    version.finish();
    if (current > SchemaVersion) {
        // A newer Saldo (the app or the widget, after an update) owns this
        // file. Never drop its tables: an old plasmashell still running the
        // previous version would otherwise ping-pong rebuilds with the app.
        execText(db, u"COMMIT"_s);
        qCWarning(SALDO_LOG) << "Database schema" << current << "is newer than" << SchemaVersion << "- restart to load the new version";
        return;
    }

    bool stale = current != SchemaVersion;
    for (const auto &[table, column] : SentinelColumns) {
        const QString name = QString::fromLatin1(table);
        if (tableExists(db, name) && !hasColumn(db, name, QString::fromLatin1(column))) {
            qCWarning(SALDO_LOG) << "Table" << name << "lacks" << column << "- rebuilding the cache";
            stale = true;
        }
    }
    if (stale) {
        // It is only a cache: rebuild it from scratch on schema changes.
        for (const char *table : Tables) {
            execText(db, u"DROP TABLE IF EXISTS %1"_s.arg(QLatin1StringView(table)));
        }
    }
    for (const char *statement : SchemaStatements) {
        execText(db, QString::fromLatin1(statement));
    }
    execText(db, u"PRAGMA user_version=%1"_s.arg(SchemaVersion));
    execText(db, u"COMMIT"_s);
}

// RAII transaction: rolls back unless commit() succeeded.
class Transaction
{
public:
    explicit Transaction(QSqlDatabase db)
        : m_db(db)
        , m_active(m_db.transaction())
    {
    }
    ~Transaction()
    {
        if (m_active) {
            m_db.rollback();
        }
    }
    bool commit()
    {
        if (!m_active) {
            return false;
        }
        m_active = false;
        return m_db.commit();
    }

private:
    QSqlDatabase m_db;
    bool m_active;
};

bool deleteAccountData(QSqlDatabase db, const QString &accountId)
{
    for (const QString &sql : {u"DELETE FROM transactions WHERE account_id = ?"_s, u"DELETE FROM bills WHERE account_id = ?"_s, u"DELETE FROM accounts WHERE id = ?"_s}) {
        QSqlQuery query(db);
        query.prepare(sql);
        query.addBindValue(accountId);
        if (!exec(query)) {
            return false;
        }
    }
    return true;
}

bool deleteItemData(QSqlDatabase db, const QString &itemId)
{
    QSqlQuery accounts(db);
    accounts.prepare(u"SELECT id FROM accounts WHERE item_id = ?"_s);
    accounts.addBindValue(itemId);
    if (!exec(accounts)) {
        return false;
    }
    QStringList accountIds;
    while (accounts.next()) {
        accountIds.append(accounts.value(0).toString());
    }
    for (const QString &accountId : std::as_const(accountIds)) {
        if (!deleteAccountData(db, accountId)) {
            return false;
        }
    }
    for (const QString &sql : {u"DELETE FROM investments WHERE item_id = ?"_s, u"DELETE FROM items WHERE id = ?"_s}) {
        QSqlQuery query(db);
        query.prepare(sql);
        query.addBindValue(itemId);
        if (!exec(query)) {
            return false;
        }
    }
    return true;
}
}

Database *Database::instance()
{
    static Database *database = new Database(QCoreApplication::instance());
    return database;
}

Database::Database(QObject *parent)
    : QObject(parent)
{
    connection(); // create the file and schema early

    if (Paths::isDemo() && isEmpty()) {
        DemoData::populate();
    }

    QFile stamp(Paths::stampFile());
    if (stamp.open(QIODevice::ReadOnly)) {
        m_lastStamp = stamp.readAll();
    }
    watchStamp();
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &Database::onWatcherEvent);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Database::onWatcherEvent);
}

QSqlDatabase Database::connection()
{
    const QString name = connectionName();
    if (QSqlDatabase::contains(name)) {
        return QSqlDatabase::database(name);
    }
    QSqlDatabase db = QSqlDatabase::addDatabase(u"QSQLITE"_s, name);
    const QString file = Paths::databaseFile();
    db.setDatabaseName(file);
    if (!db.open()) {
        qCWarning(SALDO_LOG) << "Cannot open database" << file << db.lastError().text();
        return db;
    }
    QFile::setPermissions(file, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    ensureSchema(db);
    return db;
}

void Database::closeThreadConnection()
{
    const QString name = connectionName();
    if (QSqlDatabase::contains(name)) {
        QSqlDatabase::database(name).close();
        QSqlDatabase::removeDatabase(name);
    }
}

QString Database::meta(const QString &key)
{
    QSqlQuery query(connection());
    query.prepare(u"SELECT value FROM meta WHERE key = ?"_s);
    query.addBindValue(key);
    if (exec(query) && query.next()) {
        return query.value(0).toString();
    }
    return QString();
}

void Database::setMeta(const QString &key, const QString &value)
{
    QSqlQuery query(connection());
    query.prepare(u"INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)"_s);
    query.addBindValue(key);
    query.addBindValue(value);
    exec(query);
}

QDateTime Database::itemLastUpdated(const QString &itemId)
{
    QSqlQuery query(connection());
    query.prepare(u"SELECT last_updated_at FROM items WHERE id = ?"_s);
    query.addBindValue(itemId);
    if (exec(query) && query.next()) {
        return QDateTime::fromString(query.value(0).toString(), Qt::ISODateWithMs);
    }
    return {};
}

bool Database::hasAccounts(const QString &itemId)
{
    QSqlQuery query(connection());
    query.prepare(u"SELECT 1 FROM accounts WHERE item_id = ? LIMIT 1"_s);
    query.addBindValue(itemId);
    return exec(query) && query.next();
}

bool Database::isEmpty()
{
    QSqlQuery query(connection());
    query.prepare(u"SELECT 1 FROM accounts LIMIT 1"_s);
    return !(exec(query) && query.next());
}

bool Database::upsertItem(const ItemRecord &item)
{
    QSqlDatabase db = connection();
    QSqlQuery query(db);
    query.prepare(
        u"INSERT OR REPLACE INTO items (id, connector_name, connector_image, status, execution_status, error_code,"
        " error_message, last_updated_at, consent_expires_at, next_auto_sync_at, raw)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"_s);
    query.addBindValue(item.id);
    query.addBindValue(item.connectorName);
    query.addBindValue(item.connectorImageUrl);
    query.addBindValue(item.status);
    query.addBindValue(item.executionStatus);
    query.addBindValue(item.errorCode);
    query.addBindValue(item.errorMessage);
    query.addBindValue(dateTimeValue(item.lastUpdatedAt));
    query.addBindValue(dateTimeValue(item.consentExpiresAt));
    query.addBindValue(dateTimeValue(item.nextAutoSyncAt));
    query.addBindValue(QString::fromUtf8(item.raw));
    return exec(query);
}

bool Database::replaceAccounts(const QString &itemId, const QList<AccountRecord> &accounts)
{
    QSqlDatabase db = connection();
    Transaction transaction(db);

    QSet<QString> keep;
    for (const AccountRecord &account : accounts) {
        keep.insert(account.id);
    }
    QSqlQuery existing(db);
    existing.prepare(u"SELECT id FROM accounts WHERE item_id = ?"_s);
    existing.addBindValue(itemId);
    if (!exec(existing)) {
        return false;
    }
    QStringList gone;
    while (existing.next()) {
        const QString id = existing.value(0).toString();
        if (!keep.contains(id)) {
            gone.append(id);
        }
    }
    for (const QString &id : std::as_const(gone)) {
        if (!deleteAccountData(db, id)) {
            return false;
        }
    }

    QSqlQuery insert(db);
    insert.prepare(
        u"INSERT OR REPLACE INTO accounts (id, item_id, type, subtype, name, marketing_name, number, owner, currency,"
        " balance, has_credit, credit_limit, available_credit_limit, minimum_payment, close_date, due_date, brand,"
        " level, holder_type, credit_status, tax_number, raw) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"_s);
    for (const AccountRecord &a : accounts) {
        insert.addBindValue(a.id);
        insert.addBindValue(itemId);
        insert.addBindValue(a.type);
        insert.addBindValue(a.subtype);
        insert.addBindValue(a.name);
        insert.addBindValue(a.marketingName);
        insert.addBindValue(a.number);
        insert.addBindValue(a.owner);
        insert.addBindValue(a.currency);
        insert.addBindValue(a.balance);
        insert.addBindValue(a.hasCredit ? 1 : 0);
        insert.addBindValue(a.creditLimit);
        insert.addBindValue(a.availableCreditLimit);
        insert.addBindValue(a.minimumPayment);
        insert.addBindValue(dateValue(a.closeDate));
        insert.addBindValue(dateValue(a.dueDate));
        insert.addBindValue(a.brand);
        insert.addBindValue(a.level);
        insert.addBindValue(a.holderType);
        insert.addBindValue(a.creditStatus);
        insert.addBindValue(a.taxNumber);
        insert.addBindValue(QString::fromUtf8(a.raw));
        if (!exec(insert)) {
            return false;
        }
    }
    return transaction.commit();
}

bool Database::replaceTransactions(const QString &accountId, const QDate &from, const QList<TransactionRecord> &transactions)
{
    QSqlDatabase db = connection();
    Transaction transaction(db);

    QSqlQuery remove(db);
    if (from.isValid()) {
        remove.prepare(u"DELETE FROM transactions WHERE account_id = ? AND date >= ?"_s);
        remove.addBindValue(accountId);
        remove.addBindValue(from.toString(Qt::ISODate));
    } else {
        remove.prepare(u"DELETE FROM transactions WHERE account_id = ?"_s);
        remove.addBindValue(accountId);
    }
    if (!exec(remove)) {
        return false;
    }

    QSqlQuery insert(db);
    insert.prepare(
        u"INSERT OR REPLACE INTO transactions (id, account_id, date, description, amount, normalized_amount, currency,"
        " category, category_id, type, status, merchant, installment_number, total_installments, bill_id,"
        " counterparty_name, counterparty_document) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"_s);
    for (const TransactionRecord &t : transactions) {
        insert.addBindValue(t.id);
        insert.addBindValue(accountId);
        insert.addBindValue(dateValue(t.date));
        insert.addBindValue(t.description);
        insert.addBindValue(t.amount);
        insert.addBindValue(t.normalizedAmount);
        insert.addBindValue(t.currency);
        insert.addBindValue(t.category);
        insert.addBindValue(t.categoryId);
        insert.addBindValue(t.type);
        insert.addBindValue(t.status);
        insert.addBindValue(t.merchant);
        insert.addBindValue(t.installmentNumber);
        insert.addBindValue(t.totalInstallments);
        insert.addBindValue(t.billId);
        insert.addBindValue(t.counterpartyName);
        insert.addBindValue(t.counterpartyDocument);
        if (!exec(insert)) {
            return false;
        }
    }
    return transaction.commit();
}

bool Database::replaceBills(const QString &accountId, const QList<BillRecord> &bills)
{
    QSqlDatabase db = connection();
    Transaction transaction(db);

    QSqlQuery remove(db);
    remove.prepare(u"DELETE FROM bills WHERE account_id = ?"_s);
    remove.addBindValue(accountId);
    if (!exec(remove)) {
        return false;
    }
    QSqlQuery insert(db);
    insert.prepare(
        u"INSERT OR REPLACE INTO bills (id, account_id, due_date, closing_date, total_amount, minimum_payment, currency, raw)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?)"_s);
    for (const BillRecord &b : bills) {
        insert.addBindValue(b.id);
        insert.addBindValue(accountId);
        insert.addBindValue(dateValue(b.dueDate));
        insert.addBindValue(dateValue(b.closingDate));
        insert.addBindValue(b.totalAmount);
        insert.addBindValue(b.minimumPayment);
        insert.addBindValue(b.currency);
        insert.addBindValue(QString::fromUtf8(b.raw));
        if (!exec(insert)) {
            return false;
        }
    }
    return transaction.commit();
}

bool Database::replaceInvestments(const QString &itemId, const QList<InvestmentRecord> &investments)
{
    QSqlDatabase db = connection();
    Transaction transaction(db);

    QSqlQuery remove(db);
    remove.prepare(u"DELETE FROM investments WHERE item_id = ?"_s);
    remove.addBindValue(itemId);
    if (!exec(remove)) {
        return false;
    }
    QSqlQuery insert(db);
    insert.prepare(
        u"INSERT OR REPLACE INTO investments (id, item_id, name, code, type, subtype, currency, status, institution,"
        " balance, amount, amount_profit, annual_rate, last_month_rate, last_twelve_months_rate, date, due_date, raw)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"_s);
    for (const InvestmentRecord &i : investments) {
        insert.addBindValue(i.id);
        insert.addBindValue(itemId);
        insert.addBindValue(i.name);
        insert.addBindValue(i.code);
        insert.addBindValue(i.type);
        insert.addBindValue(i.subtype);
        insert.addBindValue(i.currency);
        insert.addBindValue(i.status);
        insert.addBindValue(i.institution);
        insert.addBindValue(i.balance);
        insert.addBindValue(i.amount);
        insert.addBindValue(i.amountProfit);
        insert.addBindValue(i.annualRate);
        insert.addBindValue(i.lastMonthRate);
        insert.addBindValue(i.lastTwelveMonthsRate);
        insert.addBindValue(dateValue(i.date));
        insert.addBindValue(dateValue(i.dueDate));
        insert.addBindValue(QString::fromUtf8(i.raw));
        if (!exec(insert)) {
            return false;
        }
    }
    return transaction.commit();
}

bool Database::replaceCategories(const QList<CategoryRecord> &categories)
{
    QSqlDatabase db = connection();
    Transaction transaction(db);
    if (!execText(db, u"DELETE FROM categories"_s)) {
        return false;
    }
    QSqlQuery insert(db);
    insert.prepare(
        u"INSERT OR REPLACE INTO categories (id, description, description_translated, parent_id, parent_description)"
        " VALUES (?, ?, ?, ?, ?)"_s);
    for (const CategoryRecord &c : categories) {
        insert.addBindValue(c.id);
        insert.addBindValue(c.description);
        insert.addBindValue(c.descriptionTranslated);
        insert.addBindValue(c.parentId);
        insert.addBindValue(c.parentDescription);
        if (!exec(insert)) {
            return false;
        }
    }
    return transaction.commit();
}

bool Database::removeItemsNotIn(const QStringList &itemIds)
{
    QSqlDatabase db = connection();
    Transaction transaction(db);
    QSqlQuery items(db);
    if (!items.exec(u"SELECT DISTINCT item_id FROM accounts UNION SELECT id FROM items UNION SELECT DISTINCT item_id FROM investments"_s)) {
        return false;
    }
    QStringList gone;
    while (items.next()) {
        const QString id = items.value(0).toString();
        if (!itemIds.contains(id)) {
            gone.append(id);
        }
    }
    for (const QString &id : std::as_const(gone)) {
        if (!deleteItemData(db, id)) {
            return false;
        }
    }
    return transaction.commit();
}

bool Database::clearAll()
{
    QSqlDatabase db = connection();
    Transaction transaction(db);
    for (const char *table : Tables) {
        if (!execText(db, u"DELETE FROM %1"_s.arg(QLatin1StringView(table)))) {
            return false;
        }
    }
    return transaction.commit();
}

namespace
{
struct TxRow {
    QString id;
    QString account;
    bool card = false;
    QString category; // lowercase
    QDate date;
    qint64 cents = 0; // normalized, signed
    QString document;
    int internal = 0;
    QString reason;
    QString match;
};

bool transferLike(const QString &category)
{
    return category.contains("transf"_L1) || category.contains("pix"_L1) || category.startsWith("same person"_L1)
        || category.startsWith("credit card payment"_L1);
}

// Greedy one-to-one matching: each outflow takes the closest unmatched inflow
// of exactly the same amount within [minDays, maxDays] (in - out).
void matchPairs(QList<TxRow> &rows,
                const std::function<bool(const TxRow &)> &isOut,
                const std::function<bool(const TxRow &)> &isIn,
                int minDays,
                int maxDays,
                const QString &reason,
                QSet<int> &used)
{
    QHash<qint64, QList<int>> inflows;
    for (int i = 0; i < rows.size(); ++i) {
        if (!used.contains(i) && rows.at(i).cents > 0 && isIn(rows.at(i))) {
            inflows[rows.at(i).cents].append(i);
        }
    }
    QList<int> outflows;
    for (int i = 0; i < rows.size(); ++i) {
        if (!used.contains(i) && rows.at(i).cents < 0 && isOut(rows.at(i))) {
            outflows.append(i);
        }
    }
    std::sort(outflows.begin(), outflows.end(), [&rows](int a, int b) {
        return rows.at(a).date < rows.at(b).date;
    });
    for (int o : std::as_const(outflows)) {
        const TxRow &out = rows.at(o);
        const QList<int> candidates = inflows.value(-out.cents);
        int best = -1;
        qint64 bestDistance = std::numeric_limits<qint64>::max();
        for (int i : candidates) {
            if (used.contains(i) || rows.at(i).account == out.account) {
                continue;
            }
            const qint64 days = out.date.daysTo(rows.at(i).date);
            if (days < minDays || days > maxDays) {
                continue;
            }
            if (std::abs(days) < bestDistance) {
                bestDistance = std::abs(days);
                best = i;
            }
        }
        if (best < 0) {
            continue;
        }
        used.insert(o);
        used.insert(best);
        for (const auto &[self, other] : {std::pair{o, best}, std::pair{best, o}}) {
            TxRow &row = rows[self];
            if (!row.internal) {
                row.internal = 1;
                row.reason = reason;
            }
            row.match = rows.at(other).id;
        }
    }
}
}

bool Database::detectInternalTransfers()
{
    QSqlDatabase db = connection();
    Transaction transaction(db);

    QSet<QString> ownDocuments;
    QSqlQuery docs(db);
    if (!docs.exec(u"SELECT DISTINCT tax_number FROM accounts WHERE COALESCE(tax_number, '') <> ''"_s)) {
        return false;
    }
    while (docs.next()) {
        ownDocuments.insert(docs.value(0).toString());
    }

    QList<TxRow> rows;
    QSqlQuery load(db);
    if (!load.exec(u"SELECT t.id, t.account_id, a.type, lower(COALESCE(t.category, '')), t.date, t.normalized_amount,"
                   " COALESCE(t.counterparty_document, '') FROM transactions t JOIN accounts a ON a.id = t.account_id"_s)) {
        return false;
    }
    while (load.next()) {
        TxRow row;
        row.id = load.value(0).toString();
        row.account = load.value(1).toString();
        row.card = load.value(2).toString() == "CREDIT"_L1;
        row.category = load.value(3).toString();
        row.date = QDate::fromString(load.value(4).toString(), Qt::ISODate);
        row.cents = std::llround(load.value(5).toDouble() * 100);
        row.document = load.value(6).toString();
        // Rule 1: Pluggy already says so.
        if (row.category.startsWith("same person transfer"_L1) || row.category.startsWith("credit card payment"_L1)) {
            row.internal = 1;
            row.reason = u"category"_s;
        }
        // Rule 2: PIX/TED to or from the user's own CPF/CNPJ.
        else if (!row.document.isEmpty() && ownDocuments.contains(row.document)) {
            row.internal = 1;
            row.reason = u"document"_s;
        }
        rows.append(row);
    }

    QSet<int> used;
    // Rule 3: same amount leaves one connected bank account and arrives in
    // another within 3 days, both sides being transfers.
    matchPairs(
        rows,
        [](const TxRow &r) {
            return !r.card && transferLike(r.category);
        },
        [](const TxRow &r) {
            return !r.card && transferLike(r.category);
        },
        -3,
        3,
        u"pair"_s,
        used);
    // Rule 4: card bill paid from a connected bank account. Money arriving on
    // a card is a payment or a refund, so any card category qualifies.
    matchPairs(
        rows,
        [](const TxRow &r) {
            return !r.card && transferLike(r.category);
        },
        [](const TxRow &r) {
            return r.card;
        },
        -2,
        7,
        u"card-payment"_s,
        used);

    // Manual overrides win.
    QSqlQuery overrides(db);
    if (!overrides.exec(u"SELECT id, internal FROM transaction_overrides"_s)) {
        return false;
    }
    QHash<QString, int> manual;
    while (overrides.next()) {
        manual.insert(overrides.value(0).toString(), overrides.value(1).toInt());
    }

    QSqlQuery update(db);
    update.prepare(u"UPDATE transactions SET internal = ?, internal_reason = ?, internal_match = ? WHERE id = ?"_s);
    for (TxRow &row : rows) {
        const auto it = manual.constFind(row.id);
        if (it != manual.constEnd()) {
            row.internal = it.value() ? 1 : 0;
            row.reason = it.value() ? u"manual"_s : u"manual-counted"_s;
        }
        update.addBindValue(row.internal);
        update.addBindValue(row.reason.isEmpty() ? QVariant() : QVariant(row.reason));
        update.addBindValue(row.match.isEmpty() ? QVariant() : QVariant(row.match));
        update.addBindValue(row.id);
        if (!exec(update)) {
            return false;
        }
    }
    return transaction.commit();
}

bool Database::setInternalOverride(const QString &transactionId, int value)
{
    QSqlQuery query(connection());
    if (value < 0) {
        query.prepare(u"DELETE FROM transaction_overrides WHERE id = ?"_s);
        query.addBindValue(transactionId);
    } else {
        query.prepare(u"INSERT OR REPLACE INTO transaction_overrides (id, internal) VALUES (?, ?)"_s);
        query.addBindValue(transactionId);
        query.addBindValue(value ? 1 : 0);
    }
    return exec(query) && detectInternalTransfers();
}

bool Database::recordBalanceSnapshot(const QDate &day)
{
    QSqlQuery query(connection());
    query.prepare(u"INSERT OR REPLACE INTO balance_snapshots (day, account_id, balance) SELECT ?, id, balance FROM accounts WHERE type = 'BANK'"_s);
    query.addBindValue(day.toString(Qt::ISODate));
    return exec(query);
}

QString Database::countedSql()
{
    return u"t.internal = 0"_s;
}

QString Database::incomeSql()
{
    return u"COALESCE(SUM(CASE WHEN a.type <> 'CREDIT' AND t.normalized_amount > 0 THEN t.normalized_amount END), 0)"_s;
}

QString Database::expenseSql()
{
    return u"(COALESCE(SUM(CASE WHEN t.normalized_amount < 0 THEN -t.normalized_amount END), 0)"
           " - COALESCE(SUM(CASE WHEN a.type = 'CREDIT' AND t.normalized_amount > 0 THEN t.normalized_amount END), 0))"_s;
}

void Database::notifyChanged()
{
    const QByteArray stamp = QByteArray::number(QDateTime::currentMSecsSinceEpoch());
    QSaveFile file(Paths::stampFile());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(stamp);
        if (file.commit()) {
            m_lastStamp = stamp;
        }
    }
    watchStamp();
    Q_EMIT dataChanged();
}

void Database::watchStamp()
{
    const QString stamp = Paths::stampFile();
    const QString dir = QFileInfo(stamp).absolutePath();
    if (!m_watcher.directories().contains(dir)) {
        m_watcher.addPath(dir);
    }
    if (QFileInfo::exists(stamp) && !m_watcher.files().contains(stamp)) {
        m_watcher.addPath(stamp);
    }
}

void Database::onWatcherEvent()
{
    watchStamp();
    QFile file(Paths::stampFile());
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }
    const QByteArray stamp = file.readAll();
    if (!stamp.isEmpty() && stamp != m_lastStamp) {
        m_lastStamp = stamp;
        Q_EMIT dataChanged(); // written by the other process
    }
}
