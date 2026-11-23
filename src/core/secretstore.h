// SPDX-License-Identifier: MIT
#pragma once

#include <QObject>

#include <functional>

// Stores one secret blob in the system keyring, asynchronously.
//
// Desktop: secret-tool (libsecret → Secret Service / KWallet), driven with an
// async QProcess. Android (or SALDO_USE_QTKEYCHAIN): QtKeychain, backed by the
// Android Keystore. The secret never touches a file.
class SecretStore : public QObject
{
    Q_OBJECT

public:
    using ReadCallback = std::function<void(bool found, const QByteArray &secret, const QString &error)>;
    using WriteCallback = std::function<void(bool ok, const QString &error)>;

    explicit SecretStore(QObject *parent = nullptr);

    // Whether a keyring backend is usable (secret-tool installed, ...).
    static bool isAvailable();
    static QString unavailableReason();

    void read(ReadCallback callback);
    void write(const QByteArray &secret, WriteCallback callback);
    void remove(WriteCallback callback);
};
