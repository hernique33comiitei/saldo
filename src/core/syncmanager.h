// SPDX-License-Identifier: MIT
#pragma once

#include "records.h"
#include "saldocore_export.h"

#include <QDateTime>
#include <QLockFile>
#include <QObject>
#include <QQmlEngine>
#include <QThreadPool>
#include <QTimer>

#include <functional>
#include <memory>

class PluggyClient;

// Fetches everything from Pluggy into the local cache.
//
// Runs in-process (no daemon): Meu Pluggy refreshes its data once a day, so the
// app and the widget each poll on a timer and skip the work when the other one
// synced recently. A lock file guarantees a single sync at a time. Database
// writes run on a dedicated worker thread to keep the UI responsive.
class SALDOCORE_EXPORT SyncManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString progressText READ progressText NOTIFY progressTextChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QDateTime lastSyncAt READ lastSyncAt NOTIFY lastSyncAtChanged)
    Q_PROPERTY(bool testing READ testing NOTIFY testingChanged)

public:
    static SyncManager *instance();
    static SyncManager *create(QQmlEngine *, QJSEngine *);
    ~SyncManager() override;

    bool running() const;
    QString progressText() const;
    QString lastError() const;
    QDateTime lastSyncAt() const;
    bool testing() const;

    // User-triggered: always fetches.
    Q_INVOKABLE void sync();
    // Timer/startup: only when the last sync is older than the refresh interval.
    Q_INVOKABLE void syncIfStale();
    // Empty clientSecret = use the stored one.
    Q_INVOKABLE void testConnection(const QString &clientId, const QString &clientSecret);
    Q_INVOKABLE void validateItem(const QString &itemId);
    Q_INVOKABLE void clearCache();
    Q_INVOKABLE void dismissError();

Q_SIGNALS:
    void runningChanged();
    void progressTextChanged();
    void lastErrorChanged();
    void lastSyncAtChanged();
    void testingChanged();
    void syncFinished(bool ok);
    void connectionTested(bool ok, const QString &message);
    void itemValidated(const QString &itemId, bool ok, const QString &message);

private:
    explicit SyncManager(QObject *parent = nullptr);

    void start(bool force);
    void processNextItem();
    void fetchAccounts(const QString &itemId);
    void processNextAccount(const QString &itemId);
    void fetchInvestments(const QString &itemId);
    void fetchCategoriesIfNeeded();
    void finish();
    void finishSync();
    void fail(const QString &message);

    void runDbJob(std::function<bool()> job, std::function<void(bool ok)> done);
    QDate transactionsFrom(const QString &accountId) const;
    void setRunning(bool running);
    void setProgress(const QString &text);
    void setLastError(const QString &error);
    void restartTimer();

    PluggyClient *m_client;
    PluggyClient *m_testClient;
    QThreadPool m_dbPool;
    QTimer m_timer;
    std::unique_ptr<QLockFile> m_lock;

    bool m_running = false;
    bool m_testing = false;
    bool m_force = false;
    QString m_progress;
    QString m_lastError;
    QStringList m_errors;
    QStringList m_itemQueue;
    QList<AccountRecord> m_accountQueue;
};
