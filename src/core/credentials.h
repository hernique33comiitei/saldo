// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QObject>
#include <QQmlEngine>

#include <functional>

class SecretStore;

// Pluggy Client ID + Client Secret. Kept in the system keyring; cached in
// memory for the lifetime of the process once read.
class SALDOCORE_EXPORT Credentials : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool configured READ configured NOTIFY configuredChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY configuredChanged)
    Q_PROPERTY(QString clientId READ clientId NOTIFY configuredChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool keyringAvailable READ keyringAvailable CONSTANT)
    Q_PROPERTY(QString keyringUnavailableReason READ keyringUnavailableReason CONSTANT)

public:
    using LoadCallback = std::function<void(bool ok, const QString &clientId, const QString &clientSecret, const QString &error)>;

    static Credentials *instance();
    static Credentials *create(QQmlEngine *, QJSEngine *);

    bool configured() const;
    bool loaded() const;
    QString clientId() const;
    bool busy() const;
    QString error() const;
    bool keyringAvailable() const;
    QString keyringUnavailableReason() const;

    // Saves new credentials. An empty secret keeps the stored one (lets the
    // user change only the Client ID).
    Q_INVOKABLE void save(const QString &clientId, const QString &clientSecret);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void reload();

    // Reads the credentials (from memory when already loaded).
    void load(LoadCallback callback);

Q_SIGNALS:
    void configuredChanged();
    void busyChanged();
    void errorChanged();
    void saved();
    void cleared();

private:
    explicit Credentials(QObject *parent = nullptr);
    void setBusy(bool busy);
    void setError(const QString &error);
    void apply(bool found, const QByteArray &blob);
    void storeBlob(const QString &clientId, const QString &clientSecret);

    SecretStore *m_store;
    bool m_loaded = false;
    bool m_loading = false;
    QString m_clientId;
    QString m_clientSecret;
    bool m_busy = false;
    QString m_error;
    QList<LoadCallback> m_waiting;
};
