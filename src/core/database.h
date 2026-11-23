// SPDX-License-Identifier: MIT
#pragma once

#include "records.h"
#include "saldocore_export.h"

#include <QFileSystemWatcher>
#include <QObject>
#include <QSqlDatabase>

// Local SQLite cache of everything fetched from Pluggy.
//
// Shared by the app and the Plasma widget (WAL mode, busy timeout). Every
// static function uses a connection owned by the calling thread, so writes can
// run on a worker thread. After a sync, notifyChanged() rewrites a small stamp
// file; the other process watches it and reloads its models.
class SALDOCORE_EXPORT Database : public QObject
{
    Q_OBJECT

public:
    static Database *instance();
    static QSqlDatabase connection();

    // Must be called on the thread that used connection() before it exits.
    static void closeThreadConnection();

    static QString meta(const QString &key);
    static void setMeta(const QString &key, const QString &value);
    static QDateTime itemLastUpdated(const QString &itemId);
    static bool hasAccounts(const QString &itemId);
    static bool isEmpty();

    // Each write runs in its own SQL transaction and returns false on error.
    static bool upsertItem(const ItemRecord &item);
    static bool replaceAccounts(const QString &itemId, const QList<AccountRecord> &accounts);
    // Replaces the account's transactions dated on/after `from` (a reconcile
    // window: pending movements that vanished upstream are dropped too).
    static bool replaceTransactions(const QString &accountId, const QDate &from, const QList<TransactionRecord> &transactions);
    static bool replaceBills(const QString &accountId, const QList<BillRecord> &bills);
    static bool replaceInvestments(const QString &itemId, const QList<InvestmentRecord> &investments);
    static bool replaceCategories(const QList<CategoryRecord> &categories);
    static bool removeItemsNotIn(const QStringList &itemIds);
    static bool clearAll();

    // Marks movements between the user's own accounts (transactions.internal):
    // same-person/card-payment categories, PIX/TED to the user's own CPF/CNPJ,
    // matching out/in pairs across connected accounts and bank → card bill
    // payments. Manual overrides win. Run after every sync.
    static bool detectInternalTransfers();
    // value: 1 = between my accounts, 0 = counts as income/expense,
    // -1 = back to automatic detection. Re-runs the detection.
    static bool setInternalOverride(const QString &transactionId, int value);
    // Stores today's balance of every bank account (history for the chart:
    // reconstructing it from transactions is unreliable).
    static bool recordBalanceSnapshot(const QDate &day);

    // SQL pieces shared by every income/expense aggregate. They expect the
    // aliases t (transactions) and a (accounts, joined on t.account_id).
    // Income only comes from bank accounts; money coming into a card is a
    // refund (it lowers expenses) or a bill payment (internal).
    static QString countedSql();
    static QString incomeSql();
    static QString expenseSql();

    // Main thread: announce new data to this process and to the other one.
    void notifyChanged();

Q_SIGNALS:
    void dataChanged();

private:
    explicit Database(QObject *parent = nullptr);
    void watchStamp();
    void onWatcherEvent();

    QFileSystemWatcher m_watcher;
    QByteArray m_lastStamp;
};
