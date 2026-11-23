// SPDX-License-Identifier: MIT
#include "pluggyclient.h"

#include "logging.h"

#include <KLocalizedString>

#include <QJsonObject>
#include <QNetworkReply>
#include <QTimer>

using namespace Qt::StringLiterals;

namespace
{
constexpr int ApiKeyLifetimeSecs = 110 * 60; // keys last 2 h; renew a bit earlier
constexpr int MaxRetries = 3;
constexpr int MaxPages = 200;

QString encodeQuery(const QList<std::pair<QString, QString>> &items)
{
    QStringList parts;
    for (const auto &[key, value] : items) {
        parts.append(key + u'=' + QString::fromLatin1(QUrl::toPercentEncoding(value)));
    }
    return parts.join(u'&');
}
}

PluggyClient::PluggyClient(QObject *parent)
    : QObject(parent)
    , m_baseUrl(u"https://api.pluggy.ai"_s)
{
    m_network.setAutoDeleteReplies(true);
    m_network.setTransferTimeout(30000);
}

void PluggyClient::setCredentials(const QString &clientId, const QString &clientSecret)
{
    if (clientId != m_clientId || clientSecret != m_clientSecret) {
        m_clientId = clientId;
        m_clientSecret = clientSecret;
        m_apiKey.clear();
    }
}

void PluggyClient::setBaseUrl(const QUrl &url)
{
    m_baseUrl = url;
}

QNetworkRequest PluggyClient::request(const QString &path, const QString &query) const
{
    QUrl url = m_baseUrl;
    url.setPath(url.path() + path);
    if (!query.isEmpty()) {
        url.setQuery(query, QUrl::TolerantMode);
    }
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, u"application/json"_s);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Saldo/" SALDO_VERSION));
    request.setRawHeader("Accept", "application/json");
    if (!m_apiKey.isEmpty()) {
        request.setRawHeader("X-API-KEY", m_apiKey.toUtf8());
    }
    return request;
}

PluggyClient::Reply PluggyClient::toReply(QNetworkReply *reply) const
{
    Reply result;
    result.status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    result.json = QJsonDocument::fromJson(body);

    if (reply->error() == QNetworkReply::NoError && result.status >= 200 && result.status < 300) {
        return result;
    }

    const QString apiMessage = result.json.object().value("message"_L1).toString();
    if (result.status == 0) {
        result.error = i18n("Could not reach Pluggy: %1", reply->errorString());
    } else if (result.status == 401 || result.status == 403) {
        result.error = apiMessage.isEmpty() ? i18n("Pluggy refused the request (HTTP %1). Check the Client ID and Client Secret.", result.status)
                                            : i18n("Pluggy refused the request: %1", apiMessage);
    } else if (result.status == 404) {
        result.error = i18n("Not found on Pluggy. Check the item ID.");
    } else {
        result.error = apiMessage.isEmpty() ? i18n("Pluggy returned HTTP %1.", result.status) : i18n("Pluggy error (HTTP %1): %2", result.status, apiMessage);
    }
    return result;
}

void PluggyClient::authenticate(const Callback &callback)
{
    if (m_clientId.isEmpty() || m_clientSecret.isEmpty()) {
        callback(Reply{0, {}, i18n("Pluggy credentials are not configured.")});
        return;
    }

    const QByteArray body = QJsonDocument(QJsonObject{{u"clientId"_s, m_clientId}, {u"clientSecret"_s, m_clientSecret}}).toJson(QJsonDocument::Compact);
    m_apiKey.clear();
    QNetworkReply *reply = m_network.post(request(u"/auth"_s, QString()), body);
    connect(reply, &QNetworkReply::finished, this, [this, reply, callback]() {
        Reply result = toReply(reply);
        if (result.ok()) {
            m_apiKey = result.json.object().value("apiKey"_L1).toString();
            if (m_apiKey.isEmpty()) {
                result.error = i18n("Pluggy did not return an API key.");
            } else {
                m_apiKeyIssuedAt = QDateTime::currentDateTimeUtc();
            }
        } else if (result.status == 400 || result.status == 401 || result.status == 403) {
            result.error = i18n("Pluggy rejected the Client ID or Client Secret.");
        }
        callback(result);
    });
}

void PluggyClient::ensureApiKey(const std::function<void(const QString &error)> &callback)
{
    if (!m_apiKey.isEmpty() && m_apiKeyIssuedAt.secsTo(QDateTime::currentDateTimeUtc()) < ApiKeyLifetimeSecs) {
        callback(QString());
        return;
    }
    m_authWaiting.append(callback);
    if (m_authInFlight) {
        return;
    }
    m_authInFlight = true;
    authenticate([this](const Reply &reply) {
        m_authInFlight = false;
        const auto waiting = std::exchange(m_authWaiting, {});
        for (const auto &waiter : waiting) {
            waiter(reply.error);
        }
    });
}

void PluggyClient::get(const QString &path, const QString &query, const Callback &callback, int attempt)
{
    ensureApiKey([=, this](const QString &authError) {
        if (!authError.isEmpty()) {
            callback(Reply{0, {}, authError});
            return;
        }
        QNetworkReply *reply = m_network.get(request(path, query));
        connect(reply, &QNetworkReply::finished, this, [=, this]() {
            const Reply result = toReply(reply);
            if (result.status == 401 && attempt == 0) {
                // The key expired early or was revoked: get a new one once.
                m_apiKey.clear();
                get(path, query, callback, attempt + 1);
                return;
            }
            if (result.status == 429 && attempt < MaxRetries) {
                bool ok = false;
                int wait = reply->rawHeader("Retry-After").toInt(&ok);
                if (!ok || wait <= 0) {
                    wait = 60;
                }
                qCInfo(SALDO_LOG) << "Rate limited by Pluggy, retrying in" << wait << "s";
                QTimer::singleShot(wait * 1000, this, [=, this]() {
                    get(path, query, callback, attempt + 1);
                });
                return;
            }
            if (!result.ok()) {
                qCWarning(SALDO_LOG) << "GET" << path << "failed:" << result.status << result.error;
            }
            callback(result);
        });
    });
}

void PluggyClient::getPaged(const QString &path, const QString &query, const ArrayCallback &callback)
{
    auto results = std::make_shared<QJsonArray>();
    auto fetchPage = std::make_shared<std::function<void(int)>>();
    *fetchPage = [=, this](int page) {
        QString pageQuery = query;
        if (!pageQuery.isEmpty()) {
            pageQuery += u'&';
        }
        pageQuery += u"page=%1&pageSize=500"_s.arg(page);
        get(path, pageQuery, [=](const Reply &reply) {
            if (!reply.ok()) {
                callback({}, reply.error);
                *fetchPage = nullptr; // break the self-reference
                return;
            }
            const QJsonObject object = reply.json.object();
            const QJsonArray pageResults = object.value("results"_L1).toArray();
            for (const QJsonValue &value : pageResults) {
                results->append(value);
            }
            const int totalPages = object.value("totalPages"_L1).toInt(1);
            if (page < totalPages && page < MaxPages) {
                (*fetchPage)(page + 1);
            } else {
                callback(*results, QString());
                *fetchPage = nullptr;
            }
        });
    };
    (*fetchPage)(1);
}

void PluggyClient::getCursor(const QString &path, const QString &query, const ArrayCallback &callback)
{
    auto results = std::make_shared<QJsonArray>();
    auto pages = std::make_shared<int>(0);
    auto fetch = std::make_shared<std::function<void(const QString &)>>();
    *fetch = [=, this](const QString &pageQuery) {
        get(path, pageQuery, [=](const Reply &reply) {
            if (!reply.ok()) {
                callback({}, reply.error);
                *fetch = nullptr;
                return;
            }
            const QJsonObject object = reply.json.object();
            const QJsonArray pageResults = object.value("results"_L1).toArray();
            for (const QJsonValue &value : pageResults) {
                results->append(value);
            }
            // "next" is a ready-made query string such as "?accountId=...&after=..."
            QString next = object.value("next"_L1).toString();
            if (next.startsWith(u'?')) {
                next.remove(0, 1);
            }
            if (!next.isEmpty() && ++(*pages) < MaxPages) {
                (*fetch)(next);
            } else {
                callback(*results, QString());
                *fetch = nullptr;
            }
        });
    };
    (*fetch)(query);
}

void PluggyClient::getItem(const QString &itemId, const Callback &callback)
{
    get(u"/items/"_s + QString::fromLatin1(QUrl::toPercentEncoding(itemId)), QString(), callback);
}

void PluggyClient::getAccounts(const QString &itemId, const ArrayCallback &callback)
{
    getPaged(u"/accounts"_s, encodeQuery({{u"itemId"_s, itemId}}), callback);
}

void PluggyClient::getTransactions(const QString &accountId, const QDate &from, const ArrayCallback &callback)
{
    QList<std::pair<QString, QString>> query{{u"accountId"_s, accountId}};
    if (from.isValid()) {
        query.append({u"dateFrom"_s, from.toString(Qt::ISODate)});
    }
    getCursor(u"/v2/transactions"_s, encodeQuery(query), callback);
}

void PluggyClient::getBills(const QString &accountId, const ArrayCallback &callback)
{
    getPaged(u"/bills"_s, encodeQuery({{u"accountId"_s, accountId}}), callback);
}

void PluggyClient::getInvestments(const QString &itemId, const ArrayCallback &callback)
{
    getPaged(u"/investments"_s, encodeQuery({{u"itemId"_s, itemId}}), callback);
}

void PluggyClient::getCategories(const ArrayCallback &callback)
{
    getPaged(u"/categories"_s, QString(), callback);
}
