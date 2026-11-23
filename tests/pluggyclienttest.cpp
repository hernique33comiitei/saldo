// SPDX-License-Identifier: MIT
// PluggyClient against a local fake of the Pluggy API.
#include "pluggyclient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTest>
#include <QUrlQuery>

using namespace Qt::StringLiterals;

namespace
{
struct Request {
    QByteArray method;
    QString path;
    QUrlQuery query;
    QHash<QByteArray, QByteArray> headers;
    QByteArray body;
};

// Minimal HTTP/1.1 server: one request per connection, then close.
class FakePluggy : public QTcpServer
{
public:
    int authCalls = 0;
    int accountsCalls = 0;
    int rateLimitedCalls = 0;
    QString currentKey;
    QList<Request> requests;
    bool rejectNextAccounts = false; // simulate an expired API key
    bool rateLimitBills = false;

    FakePluggy()
    {
        connect(this, &QTcpServer::newConnection, this, [this]() {
            while (QTcpSocket *socket = nextPendingConnection()) {
                connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
                    handle(socket);
                });
            }
        });
        listen(QHostAddress::LocalHost);
    }

    QUrl url() const
    {
        return QUrl(u"http://127.0.0.1:%1"_s.arg(serverPort()));
    }

private:
    static void reply(QTcpSocket *socket, int status, const QJsonObject &json, const QByteArray &extraHeaders = {})
    {
        const QByteArray body = QJsonDocument(json).toJson(QJsonDocument::Compact);
        QByteArray response = "HTTP/1.1 " + QByteArray::number(status) + " X\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: "
            + QByteArray::number(body.size()) + "\r\n" + extraHeaders + "\r\n" + body;
        socket->write(response);
        socket->disconnectFromHost();
    }

    void handle(QTcpSocket *socket)
    {
        QByteArray data = socket->property("buffer").toByteArray() + socket->readAll();
        const int headerEnd = data.indexOf("\r\n\r\n");
        if (headerEnd < 0) {
            socket->setProperty("buffer", data);
            return;
        }
        Request request;
        const QList<QByteArray> lines = data.left(headerEnd).split('\n');
        const QList<QByteArray> first = lines.first().trimmed().split(' ');
        request.method = first.value(0);
        const QUrl target(QString::fromLatin1(first.value(1)));
        request.path = target.path();
        request.query = QUrlQuery(target.query());
        for (qsizetype i = 1; i < lines.size(); ++i) {
            const int colon = lines.at(i).indexOf(':');
            if (colon > 0) {
                request.headers.insert(lines.at(i).left(colon).trimmed().toLower(), lines.at(i).mid(colon + 1).trimmed());
            }
        }
        const int length = request.headers.value("content-length").toInt();
        if (data.size() < headerEnd + 4 + length) {
            socket->setProperty("buffer", data);
            return;
        }
        request.body = data.mid(headerEnd + 4, length);
        requests.append(request);

        if (request.path == "/auth"_L1) {
            ++authCalls;
            const QJsonObject body = QJsonDocument::fromJson(request.body).object();
            if (body.value("clientSecret"_L1).toString() != "secret"_L1) {
                reply(socket, 401, {{u"message"_s, u"Invalid credentials"_s}, {u"code"_s, 401}});
                return;
            }
            currentKey = u"key-%1"_s.arg(authCalls);
            reply(socket, 200, {{u"apiKey"_s, currentKey}});
            return;
        }

        if (QString::fromLatin1(request.headers.value("x-api-key")) != currentKey) {
            reply(socket, 401, {{u"message"_s, u"Unauthorized"_s}, {u"code"_s, 401}});
            return;
        }

        if (request.path == "/accounts"_L1) {
            ++accountsCalls;
            if (rejectNextAccounts) {
                rejectNextAccounts = false;
                currentKey = u"revoked"_s; // the key the client holds is no longer valid
                reply(socket, 401, {{u"message"_s, u"Expired"_s}});
                return;
            }
            const int page = request.query.queryItemValue(u"page"_s).toInt();
            reply(socket, 200, {{u"page"_s, page}, {u"totalPages"_s, 2}, {u"results"_s, QJsonArray{QJsonObject{{u"id"_s, u"acc-%1"_s.arg(page)}}}}});
            return;
        }

        if (request.path == "/v2/transactions"_L1) {
            const QString after = request.query.queryItemValue(u"after"_s, QUrl::FullyDecoded);
            if (after.isEmpty()) {
                reply(socket, 200, {{u"results"_s, QJsonArray{QJsonObject{{u"id"_s, u"t1"_s}}, QJsonObject{{u"id"_s, u"t2"_s}}}},
                                    {u"next"_s, u"?accountId=a&after=eyJpZCI6InQyIn0%3D"_s}});
            } else {
                reply(socket, 200, {{u"results"_s, QJsonArray{QJsonObject{{u"id"_s, QString(u"t3:"_s + after)}}}}, {u"next"_s, QJsonValue::Null}});
            }
            return;
        }

        if (request.path == "/bills"_L1) {
            if (rateLimitBills) {
                rateLimitBills = false;
                ++rateLimitedCalls;
                reply(socket, 429, {{u"message"_s, u"Too many requests"_s}, {u"code"_s, 429}}, "Retry-After: 1\r\n");
                return;
            }
            reply(socket, 200, {{u"page"_s, 1}, {u"totalPages"_s, 1}, {u"results"_s, QJsonArray{QJsonObject{{u"id"_s, u"bill-1"_s}}}}});
            return;
        }

        reply(socket, 404, {{u"message"_s, u"Not found"_s}});
    }
};
}

class PluggyClientTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void authenticateRejectsBadSecret()
    {
        FakePluggy server;
        PluggyClient client;
        client.setBaseUrl(server.url());
        client.setCredentials(u"id"_s, u"wrong"_s);

        bool done = false;
        PluggyClient::Reply result;
        client.authenticate([&](const PluggyClient::Reply &reply) {
            result = reply;
            done = true;
        });
        QTRY_VERIFY(done);
        QVERIFY(!result.ok());
        QCOMPARE(result.status, 401);
    }

    void pagedListAndKeyRenewal()
    {
        FakePluggy server;
        server.rejectNextAccounts = true;
        PluggyClient client;
        client.setBaseUrl(server.url());
        client.setCredentials(u"id"_s, u"secret"_s);

        bool done = false;
        QJsonArray results;
        QString error;
        client.getAccounts(u"item-1"_s, [&](const QJsonArray &array, const QString &e) {
            results = array;
            error = e;
            done = true;
        });
        QTRY_VERIFY(done);
        QVERIFY2(error.isEmpty(), qPrintable(error));
        // Both pages were followed.
        QCOMPARE(results.size(), 2);
        QCOMPARE(results.at(1).toObject().value("id"_L1).toString(), u"acc-2"_s);
        // The 401 caused exactly one re-authentication.
        QCOMPARE(server.authCalls, 2);
        QCOMPARE(server.requests.at(1).query.queryItemValue(u"itemId"_s), u"item-1"_s);
        QCOMPARE(server.requests.at(1).query.queryItemValue(u"pageSize"_s), u"500"_s);
    }

    void cursorTransactions()
    {
        FakePluggy server;
        PluggyClient client;
        client.setBaseUrl(server.url());
        client.setCredentials(u"id"_s, u"secret"_s);

        bool done = false;
        QJsonArray results;
        client.getTransactions(u"a"_s, QDate(2026, 1, 31), [&](const QJsonArray &array, const QString &) {
            results = array;
            done = true;
        });
        QTRY_VERIFY(done);
        QCOMPARE(results.size(), 3);
        // The opaque cursor is sent back exactly as Pluggy encoded it.
        QCOMPARE(results.at(2).toObject().value("id"_L1).toString(), u"t3:eyJpZCI6InQyIn0="_s);
        // First request carries the filters; one API key for the whole run.
        QCOMPARE(server.requests.at(1).query.queryItemValue(u"dateFrom"_s), u"2026-01-31"_s);
        QCOMPARE(server.authCalls, 1);
    }

    void retriesAfterRateLimit()
    {
        FakePluggy server;
        server.rateLimitBills = true;
        PluggyClient client;
        client.setBaseUrl(server.url());
        client.setCredentials(u"id"_s, u"secret"_s);

        bool done = false;
        QJsonArray results;
        client.getBills(u"card"_s, [&](const QJsonArray &array, const QString &) {
            results = array;
            done = true;
        });
        QTRY_VERIFY_WITH_TIMEOUT(done, 5000);
        QCOMPARE(server.rateLimitedCalls, 1);
        QCOMPARE(results.size(), 1);
    }
};

QTEST_GUILESS_MAIN(PluggyClientTest)
#include "pluggyclienttest.moc"
