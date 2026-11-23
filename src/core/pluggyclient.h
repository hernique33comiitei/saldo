// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QDate>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QObject>
#include <QUrl>

#include <functional>

// Asynchronous client for the Pluggy API (https://api.pluggy.ai), limited to
// what the Meu Pluggy personal-use flow allows.
//
// - POST /auth exchanges Client ID + Secret for an API key valid for 2 hours;
//   the key is kept in memory and renewed transparently (also on HTTP 401).
// - HTTP 429 is retried after Retry-After.
// - Page-based lists (accounts, bills, investments, categories) and the
//   cursor-based GET /v2/transactions are followed to the end.
class SALDOCORE_EXPORT PluggyClient : public QObject
{
    Q_OBJECT

public:
    struct Reply {
        int status = 0;
        QJsonDocument json;
        QString error; // user-facing; empty on success
        bool ok() const
        {
            return error.isEmpty();
        }
    };
    using Callback = std::function<void(const Reply &reply)>;
    using ArrayCallback = std::function<void(const QJsonArray &results, const QString &error)>;

    explicit PluggyClient(QObject *parent = nullptr);

    void setCredentials(const QString &clientId, const QString &clientSecret);
    void setBaseUrl(const QUrl &url);

    // Requests a fresh API key (used by "Test connection").
    void authenticate(const Callback &callback);

    void getItem(const QString &itemId, const Callback &callback);
    void getAccounts(const QString &itemId, const ArrayCallback &callback);
    void getTransactions(const QString &accountId, const QDate &from, const ArrayCallback &callback);
    void getBills(const QString &accountId, const ArrayCallback &callback);
    void getInvestments(const QString &itemId, const ArrayCallback &callback);
    void getCategories(const ArrayCallback &callback);

private:
    void ensureApiKey(const std::function<void(const QString &error)> &callback);
    void get(const QString &path, const QString &query, const Callback &callback, int attempt = 0);
    void getPaged(const QString &path, const QString &query, const ArrayCallback &callback);
    void getCursor(const QString &path, const QString &query, const ArrayCallback &callback);
    Reply toReply(QNetworkReply *reply) const;
    QNetworkRequest request(const QString &path, const QString &query) const;

    QNetworkAccessManager m_network;
    QUrl m_baseUrl;
    QString m_clientId;
    QString m_clientSecret;
    QString m_apiKey;
    QDateTime m_apiKeyIssuedAt;
    bool m_authInFlight = false;
    QList<std::function<void(const QString &)>> m_authWaiting;
};
