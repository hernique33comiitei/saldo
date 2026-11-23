// SPDX-License-Identifier: MIT
#include "syncmanager.h"

#include "config.h"
#include "credentials.h"
#include "database.h"
#include "demodata.h"
#include "logging.h"
#include "money.h"
#include "paths.h"
#include "pluggyclient.h"
#include "pluggyparser.h"

#include <KLocalizedString>

#include <QCoreApplication>
#include <QFutureWatcher>
#include <QJsonObject>
#include <QtConcurrentRun>

using namespace Qt::StringLiterals;

namespace
{
const auto MetaLastSync = u"lastSyncAt"_s;
const auto MetaCategoriesSync = u"categoriesSyncedAt"_s;
QString metaTxSynced(const QString &accountId)
{
    return u"txSyncedOn:"_s + accountId;
}
QString metaTxFrom(const QString &accountId)
{
    return u"txFrom:"_s + accountId;
}
constexpr int ReconcileDays = 7;
}

SyncManager *SyncManager::instance()
{
    static SyncManager *manager = new SyncManager(QCoreApplication::instance());
    return manager;
}

SyncManager *SyncManager::create(QQmlEngine *, QJSEngine *)
{
    SyncManager *manager = instance();
    QJSEngine::setObjectOwnership(manager, QJSEngine::CppOwnership);
    return manager;
}

SyncManager::SyncManager(QObject *parent)
    : QObject(parent)
    , m_client(new PluggyClient(this))
    , m_testClient(new PluggyClient(this))
{
    m_dbPool.setMaxThreadCount(1);
    m_dbPool.setExpiryTimeout(-1);

    Database::instance(); // starts watching for changes made by the other process
    connect(Database::instance(), &Database::dataChanged, this, &SyncManager::lastSyncAtChanged);

    connect(&m_timer, &QTimer::timeout, this, &SyncManager::syncIfStale);
    connect(Config::instance(), &Config::refreshMinutesChanged, this, &SyncManager::restartTimer);
    connect(Config::instance(), &Config::itemIdsChanged, this, [this]() {
        if (!m_running) {
            sync();
        }
    });
    connect(Credentials::instance(), &Credentials::configuredChanged, this, &SyncManager::syncIfStale);
    restartTimer();
    QTimer::singleShot(1500, this, &SyncManager::syncIfStale);

    // Close the worker thread's SQLite connection while the application
    // object still exists (QSqlDatabase needs it).
    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, [this]() {
        m_dbPool.start([]() {
            Database::closeThreadConnection();
        });
        m_dbPool.waitForDone();
    });
}

SyncManager::~SyncManager()
{
    m_dbPool.waitForDone();
}

bool SyncManager::running() const
{
    return m_running;
}

QString SyncManager::progressText() const
{
    return m_progress;
}

QString SyncManager::lastError() const
{
    return m_lastError;
}

QDateTime SyncManager::lastSyncAt() const
{
    return QDateTime::fromString(Database::meta(MetaLastSync), Qt::ISODateWithMs);
}

bool SyncManager::testing() const
{
    return m_testing;
}

void SyncManager::setRunning(bool running)
{
    if (m_running != running) {
        m_running = running;
        Q_EMIT runningChanged();
    }
}

void SyncManager::setProgress(const QString &text)
{
    if (m_progress != text) {
        m_progress = text;
        Q_EMIT progressTextChanged();
    }
}

void SyncManager::setLastError(const QString &error)
{
    if (m_lastError != error) {
        m_lastError = error;
        Q_EMIT lastErrorChanged();
    }
}

void SyncManager::dismissError()
{
    setLastError(QString());
}

void SyncManager::restartTimer()
{
    m_timer.start(Config::instance()->refreshMinutes() * 60 * 1000);
}

void SyncManager::runDbJob(std::function<bool()> job, std::function<void(bool ok)> done)
{
    auto *watcher = new QFutureWatcher<bool>(this);
    connect(watcher, &QFutureWatcher<bool>::finished, this, [watcher, done]() {
        const bool ok = watcher->result();
        watcher->deleteLater();
        done(ok);
    });
    watcher->setFuture(QtConcurrent::run(&m_dbPool, std::move(job)));
}

void SyncManager::sync()
{
    start(true);
}

void SyncManager::syncIfStale()
{
    if (m_running || Paths::isDemo()) {
        return;
    }
    if (!Credentials::instance()->configured() || Config::instance()->itemIds().isEmpty()) {
        return;
    }
    const QDateTime last = lastSyncAt();
    if (last.isValid() && last.secsTo(QDateTime::currentDateTimeUtc()) < Config::instance()->refreshMinutes() * 60) {
        return;
    }
    start(false);
}

void SyncManager::start(bool force)
{
    if (m_running) {
        return;
    }

    if (Paths::isDemo()) {
        setRunning(true);
        setProgress(i18n("Updating demo data…"));
        QTimer::singleShot(700, this, [this]() {
            runDbJob(&DemoData::populate, [this](bool) {
                Database::instance()->notifyChanged();
                setProgress(QString());
                setLastError(QString());
                setRunning(false);
                Q_EMIT lastSyncAtChanged();
                Q_EMIT syncFinished(true);
            });
        });
        return;
    }

    m_lock = std::make_unique<QLockFile>(Paths::lockFile());
    m_lock->setStaleLockTime(10 * 60 * 1000);
    if (!m_lock->tryLock(0)) {
        // The app or the widget is already syncing; its result will arrive
        // through Database::dataChanged.
        qCInfo(SALDO_LOG) << "Another Saldo process is syncing";
        m_lock.reset();
        return;
    }

    m_force = force;
    m_errors.clear();
    setLastError(QString());
    setRunning(true);
    setProgress(i18n("Reading credentials…"));

    Credentials::instance()->load([this](bool ok, const QString &clientId, const QString &clientSecret, const QString &error) {
        if (!ok) {
            fail(error.isEmpty() ? i18n("Pluggy credentials are not configured. Open Settings to add them.") : error);
            return;
        }
        const QStringList items = Config::instance()->itemIds();
        if (items.isEmpty()) {
            fail(i18n("No Meu Pluggy connection is configured. Add an item ID in Settings."));
            return;
        }
        m_client->setCredentials(clientId, clientSecret);
        m_itemQueue = items;
        runDbJob(
            [items]() {
                return Database::removeItemsNotIn(items);
            },
            [this](bool) {
                processNextItem();
            });
    });
}

void SyncManager::processNextItem()
{
    if (m_itemQueue.isEmpty()) {
        fetchCategoriesIfNeeded();
        return;
    }
    const QString itemId = m_itemQueue.takeFirst();
    setProgress(i18n("Checking connection %1…", itemId.left(8)));

    m_client->getItem(itemId, [this, itemId](const PluggyClient::Reply &reply) {
        if (!reply.ok()) {
            m_errors.append(i18n("%1: %2", Config::instance()->displayItemName(itemId, QString()), reply.error));
            processNextItem();
            return;
        }
        const ItemRecord item = PluggyParser::parseItem(reply.json.object());
        const QDateTime previous = Database::itemLastUpdated(itemId);
        const bool unchanged = previous.isValid() && previous == item.lastUpdatedAt && Database::hasAccounts(itemId);
        Database::upsertItem(item);

        if (item.status == "LOGIN_ERROR"_L1 || item.errorCode == "USER_AUTHORIZATION_EXPIRED"_L1) {
            m_errors.append(i18n("%1: the Meu Pluggy authorization expired or was revoked. Reconnect it in the Pluggy dashboard.",
                                 Config::instance()->displayItemName(itemId, item.connectorName)));
        }

        if (unchanged && !m_force) {
            processNextItem(); // Pluggy has nothing new since the last sync
            return;
        }
        fetchAccounts(itemId);
    });
}

void SyncManager::fetchAccounts(const QString &itemId)
{
    setProgress(i18n("Downloading accounts…"));
    m_client->getAccounts(itemId, [this, itemId](const QJsonArray &results, const QString &error) {
        if (!error.isEmpty()) {
            m_errors.append(error);
            processNextItem();
            return;
        }
        QList<AccountRecord> accounts;
        for (const QJsonValue &value : results) {
            accounts.append(PluggyParser::parseAccount(value.toObject()));
        }
        runDbJob(
            [itemId, accounts]() {
                return Database::replaceAccounts(itemId, accounts);
            },
            [this, itemId, accounts](bool ok) {
                if (!ok) {
                    m_errors.append(i18n("Could not save the accounts in the local cache. Restart Saldo; if it persists, use Settings → Clear Local Cache."));
                }
                m_accountQueue = accounts;
                processNextAccount(itemId);
            });
    });
}

QDate SyncManager::transactionsFrom(const QString &accountId) const
{
    const QDate wanted = QDate::currentDate().addMonths(-Config::instance()->historyMonths());
    const QDate syncedOn = QDate::fromString(Database::meta(metaTxSynced(accountId)), Qt::ISODate);
    const QDate fetchedFrom = QDate::fromString(Database::meta(metaTxFrom(accountId)), Qt::ISODate);
    if (!syncedOn.isValid() || !fetchedFrom.isValid() || wanted < fetchedFrom) {
        return wanted; // first sync, or the history setting grew
    }
    return syncedOn.addDays(-ReconcileDays);
}

void SyncManager::processNextAccount(const QString &itemId)
{
    if (m_accountQueue.isEmpty()) {
        fetchInvestments(itemId);
        return;
    }
    const AccountRecord account = m_accountQueue.takeFirst();
    const QDate from = transactionsFrom(account.id);
    setProgress(i18n("Downloading transactions: %1…", account.marketingName.isEmpty() ? account.name : account.marketingName));

    m_client->getTransactions(account.id, from, [this, itemId, account, from](const QJsonArray &results, const QString &error) {
        if (!error.isEmpty()) {
            m_errors.append(error);
            processNextAccount(itemId);
            return;
        }
        runDbJob(
            [account, from, results]() {
                QList<TransactionRecord> transactions;
                transactions.reserve(results.size());
                for (const QJsonValue &value : results) {
                    TransactionRecord t = PluggyParser::parseTransaction(value.toObject(), account.type);
                    t.accountId = account.id;
                    transactions.append(t);
                }
                if (!Database::replaceTransactions(account.id, from, transactions)) {
                    return false;
                }
                const QDate wanted = QDate::fromString(Database::meta(metaTxFrom(account.id)), Qt::ISODate);
                if (!wanted.isValid() || from < wanted) {
                    Database::setMeta(metaTxFrom(account.id), from.toString(Qt::ISODate));
                }
                Database::setMeta(metaTxSynced(account.id), QDate::currentDate().toString(Qt::ISODate));
                return true;
            },
            [this, itemId, account](bool ok) {
                if (!ok) {
                    m_errors.append(i18n("Could not save the transactions of %1 in the local cache. Restart Saldo; if it persists, use Settings → Clear Local Cache.",
                                         account.marketingName.isEmpty() ? account.name : account.marketingName));
                }
                if (account.type != "CREDIT"_L1) {
                    processNextAccount(itemId);
                    return;
                }
                // Bills are optional: not every institution provides them.
                m_client->getBills(account.id, [this, itemId, account](const QJsonArray &bills, const QString &billError) {
                    if (!billError.isEmpty()) {
                        qCInfo(SALDO_LOG) << "No bills for" << account.id << billError;
                        processNextAccount(itemId);
                        return;
                    }
                    QList<BillRecord> records;
                    for (const QJsonValue &value : bills) {
                        records.append(PluggyParser::parseBill(value.toObject(), account.id));
                    }
                    runDbJob(
                        [account, records]() {
                            return Database::replaceBills(account.id, records);
                        },
                        [this, itemId](bool) {
                            processNextAccount(itemId);
                        });
                });
            });
    });
}

void SyncManager::fetchInvestments(const QString &itemId)
{
    setProgress(i18n("Downloading investments…"));
    m_client->getInvestments(itemId, [this, itemId](const QJsonArray &results, const QString &error) {
        if (!error.isEmpty()) {
            // Optional product: missing for most bank-only connections.
            qCInfo(SALDO_LOG) << "No investments for" << itemId << error;
            processNextItem();
            return;
        }
        QList<InvestmentRecord> investments;
        for (const QJsonValue &value : results) {
            investments.append(PluggyParser::parseInvestment(value.toObject(), itemId));
        }
        runDbJob(
            [itemId, investments]() {
                return Database::replaceInvestments(itemId, investments);
            },
            [this](bool) {
                processNextItem();
            });
    });
}

void SyncManager::fetchCategoriesIfNeeded()
{
    const QDateTime last = QDateTime::fromString(Database::meta(MetaCategoriesSync), Qt::ISODateWithMs);
    if (last.isValid() && last.daysTo(QDateTime::currentDateTimeUtc()) < 7) {
        finish();
        return;
    }
    setProgress(i18n("Downloading categories…"));
    m_client->getCategories([this](const QJsonArray &results, const QString &error) {
        if (!error.isEmpty()) {
            qCInfo(SALDO_LOG) << "Categories unavailable:" << error;
            finish();
            return;
        }
        QList<CategoryRecord> categories;
        for (const QJsonValue &value : results) {
            categories.append(PluggyParser::parseCategory(value.toObject()));
        }
        runDbJob(
            [categories]() {
                if (!Database::replaceCategories(categories)) {
                    return false;
                }
                Database::setMeta(MetaCategoriesSync, QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
                return true;
            },
            [this](bool) {
                finish();
            });
    });
}

void SyncManager::finish()
{
    setProgress(i18n("Matching transfers between your accounts…"));
    runDbJob(
        []() {
            const bool detected = Database::detectInternalTransfers();
            return Database::recordBalanceSnapshot(QDate::currentDate()) && detected;
        },
        [this](bool) {
            finishSync();
        });
}

void SyncManager::finishSync()
{
    Database::setMeta(MetaLastSync, QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
    Database::instance()->notifyChanged();
    m_lock.reset();
    setProgress(QString());
    setLastError(m_errors.join(u'\n'));
    setRunning(false);
    Q_EMIT lastSyncAtChanged();
    Q_EMIT syncFinished(m_errors.isEmpty());
}

void SyncManager::fail(const QString &message)
{
    m_lock.reset();
    setProgress(QString());
    setLastError(message);
    setRunning(false);
    Q_EMIT syncFinished(false);
}

void SyncManager::testConnection(const QString &clientId, const QString &clientSecret)
{
    if (m_testing) {
        return;
    }
    m_testing = true;
    Q_EMIT testingChanged();

    auto run = [this](const QString &id, const QString &secret) {
        m_testClient->setCredentials(id.trimmed(), secret.trimmed());
        m_testClient->authenticate([this](const PluggyClient::Reply &reply) {
            m_testing = false;
            Q_EMIT testingChanged();
            Q_EMIT connectionTested(reply.ok(), reply.ok() ? i18n("Connected to Pluggy.") : reply.error);
        });
    };

    if (!clientSecret.trimmed().isEmpty() || Paths::isDemo()) {
        run(clientId, Paths::isDemo() ? u"demo"_s : clientSecret);
        return;
    }
    Credentials::instance()->load([clientId, run](bool, const QString &storedId, const QString &storedSecret, const QString &) {
        run(clientId.trimmed().isEmpty() ? storedId : clientId, storedSecret);
    });
}

void SyncManager::validateItem(const QString &itemId)
{
    if (Paths::isDemo()) {
        Q_EMIT itemValidated(itemId, true, i18n("Demo connection"));
        return;
    }
    Credentials::instance()->load([this, itemId](bool ok, const QString &clientId, const QString &clientSecret, const QString &error) {
        if (!ok) {
            Q_EMIT itemValidated(itemId, false, error.isEmpty() ? i18n("Save the Pluggy credentials first.") : error);
            return;
        }
        m_testClient->setCredentials(clientId, clientSecret);
        m_testClient->getItem(itemId, [this, itemId](const PluggyClient::Reply &reply) {
            if (!reply.ok()) {
                Q_EMIT itemValidated(itemId, false, reply.error);
                return;
            }
            const ItemRecord item = PluggyParser::parseItem(reply.json.object());
            Q_EMIT itemValidated(itemId,
                                 true,
                                 i18nc("%1 connector name, %2 status, %3 relative time",
                                       "%1 · %2 · updated %3",
                                       item.connectorName,
                                       item.status,
                                       MoneyFormat::relativeTime(item.lastUpdatedAt)));
        });
    });
}

void SyncManager::clearCache()
{
    if (m_running) {
        return;
    }
    runDbJob(&Database::clearAll, [this](bool) {
        Database::instance()->notifyChanged();
        Q_EMIT lastSyncAtChanged();
    });
}
