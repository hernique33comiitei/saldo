// SPDX-License-Identifier: MIT
#include "credentials.h"

#include "config.h"
#include "paths.h"
#include "secretstore.h"

#include <KLocalizedString>

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>

using namespace Qt::StringLiterals;

Credentials *Credentials::instance()
{
    static Credentials *credentials = new Credentials(QCoreApplication::instance());
    return credentials;
}

Credentials *Credentials::create(QQmlEngine *, QJSEngine *)
{
    Credentials *credentials = instance();
    QJSEngine::setObjectOwnership(credentials, QJSEngine::CppOwnership);
    return credentials;
}

Credentials::Credentials(QObject *parent)
    : QObject(parent)
    , m_store(new SecretStore(this))
{
    // Another process (app ↔ widget) saved or cleared the credentials.
    connect(Config::instance(), &Config::credentialsRevisionChanged, this, &Credentials::reload);
    reload();
}

bool Credentials::configured() const
{
    if (Paths::isDemo()) {
        return true;
    }
    return !m_clientId.isEmpty() && !m_clientSecret.isEmpty();
}

bool Credentials::loaded() const
{
    return m_loaded || Paths::isDemo();
}

QString Credentials::clientId() const
{
    return m_clientId;
}

bool Credentials::busy() const
{
    return m_busy;
}

QString Credentials::error() const
{
    return m_error;
}

bool Credentials::keyringAvailable() const
{
    return Paths::isDemo() || SecretStore::isAvailable();
}

QString Credentials::keyringUnavailableReason() const
{
    return SecretStore::unavailableReason();
}

void Credentials::setBusy(bool busy)
{
    if (m_busy != busy) {
        m_busy = busy;
        Q_EMIT busyChanged();
    }
}

void Credentials::setError(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        Q_EMIT errorChanged();
    }
}

void Credentials::apply(bool found, const QByteArray &blob)
{
    m_clientId.clear();
    m_clientSecret.clear();
    if (found) {
        const QJsonObject object = QJsonDocument::fromJson(blob).object();
        m_clientId = object.value("clientId"_L1).toString();
        m_clientSecret = object.value("clientSecret"_L1).toString();
    }
    m_loaded = true;
    Q_EMIT configuredChanged();
}

void Credentials::reload()
{
    if (Paths::isDemo() || !SecretStore::isAvailable() || m_loading) {
        m_loaded = true;
        return;
    }
    m_loading = true;
    m_store->read([this](bool found, const QByteArray &secret, const QString &error) {
        m_loading = false;
        setError(error);
        apply(found, secret);
        const auto waiting = std::exchange(m_waiting, {});
        for (const LoadCallback &callback : waiting) {
            callback(configured(), m_clientId, m_clientSecret, error);
        }
    });
}

void Credentials::load(LoadCallback callback)
{
    if (Paths::isDemo()) {
        callback(true, u"demo"_s, u"demo"_s, QString());
        return;
    }
    if (!SecretStore::isAvailable()) {
        callback(false, {}, {}, SecretStore::unavailableReason());
        return;
    }
    if (m_loaded && !m_loading) {
        callback(configured(), m_clientId, m_clientSecret, m_error);
        return;
    }
    m_waiting.append(callback);
    if (!m_loading) {
        reload();
    }
}

void Credentials::storeBlob(const QString &clientId, const QString &clientSecret)
{
    const QByteArray blob = QJsonDocument(QJsonObject{{u"clientId"_s, clientId}, {u"clientSecret"_s, clientSecret}}).toJson(QJsonDocument::Compact);
    setBusy(true);
    m_store->write(blob, [this, clientId, clientSecret](bool ok, const QString &error) {
        setBusy(false);
        if (!ok) {
            setError(error.isEmpty() ? i18n("Could not save the credentials in the keyring.") : error);
            return;
        }
        setError(QString());
        m_clientId = clientId;
        m_clientSecret = clientSecret;
        m_loaded = true;
        Q_EMIT configuredChanged();
        Config::instance()->bumpCredentialsRevision();
        Q_EMIT saved();
    });
}

void Credentials::save(const QString &clientId, const QString &clientSecret)
{
    const QString id = clientId.trimmed();
    QString secret = clientSecret.trimmed();
    if (id.isEmpty()) {
        setError(i18n("The Client ID is required."));
        return;
    }
    if (secret.isEmpty()) {
        secret = m_clientSecret;
    }
    if (secret.isEmpty()) {
        setError(i18n("The Client Secret is required."));
        return;
    }
    if (secret == id) {
        setError(i18n("The Client Secret is a different value from the Client ID."));
        return;
    }
    storeBlob(id, secret);
}

void Credentials::clear()
{
    setBusy(true);
    m_store->remove([this](bool ok, const QString &error) {
        setBusy(false);
        if (!ok) {
            setError(error);
            return;
        }
        setError(QString());
        apply(false, {});
        Config::instance()->bumpCredentialsRevision();
        Q_EMIT cleared();
    });
}
