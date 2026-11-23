// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QFileSystemWatcher>
#include <QObject>
#include <QQmlEngine>
#include <QSettings>

// Preferences, persisted with QSettings in an explicit file shared by the app
// and the Plasma widget. Changes made by one process are picked up by the
// other through a file watcher. Never holds secrets.
class SALDOCORE_EXPORT Config : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList itemIds READ itemIds WRITE setItemIds NOTIFY itemIdsChanged)
    Q_PROPERTY(int historyMonths READ historyMonths WRITE setHistoryMonths NOTIFY historyMonthsChanged)
    Q_PROPERTY(int refreshMinutes READ refreshMinutes WRITE setRefreshMinutes NOTIFY refreshMinutesChanged)
    Q_PROPERTY(bool privacyMode READ privacyMode WRITE setPrivacyMode NOTIFY privacyModeChanged)
    Q_PROPERTY(QStringList excludedCardIds READ excludedCardIds NOTIFY excludedCardIdsChanged)
    Q_PROPERTY(int credentialsRevision READ credentialsRevision NOTIFY credentialsRevisionChanged)
    // Furthest step the user confirmed in the setup guide (steps without a
    // checkable outcome, such as "I connected MeuPluggy").
    Q_PROPERTY(int setupStep READ setupStep WRITE setSetupStep NOTIFY setupStepChanged)

public:
    static constexpr int MaxItems = 5; // Meu Pluggy personal use allows up to 5 connections

    static Config *instance();
    static Config *create(QQmlEngine *, QJSEngine *);

    QStringList itemIds() const;
    void setItemIds(const QStringList &ids);
    int historyMonths() const;
    void setHistoryMonths(int months);
    int refreshMinutes() const;
    void setRefreshMinutes(int minutes);
    bool privacyMode() const;
    void setPrivacyMode(bool enabled);
    QStringList excludedCardIds() const;
    int credentialsRevision() const;
    int setupStep() const;
    void setSetupStep(int step);

    Q_INVOKABLE static bool isValidItemId(const QString &id);
    // Every UUID found in pasted text (lowercase, in order, without duplicates):
    // lets users paste a whole line or several item IDs at once.
    Q_INVOKABLE static QStringList findIds(const QString &text);
    // Returns an empty string on success, otherwise a user-facing error.
    Q_INVOKABLE QString addItemId(const QString &id);
    Q_INVOKABLE void removeItemId(const QString &id);
    // User-given names for connections ("Nubank"): every Meu Pluggy item is
    // called "MeuPluggy" by Pluggy, one item per authorized bank.
    Q_INVOKABLE QString itemName(const QString &itemId) const;
    Q_INVOKABLE void setItemName(const QString &itemId, const QString &name);
    // Name to show: the user's name, else the connector name unless it is the
    // generic "MeuPluggy", else "Meu Pluggy · <id start>".
    QString displayItemName(const QString &itemId, const QString &connectorName) const;

    Q_INVOKABLE bool isCardIncluded(const QString &accountId) const;
    Q_INVOKABLE void setCardIncluded(const QString &accountId, bool included);

    void bumpCredentialsRevision();

Q_SIGNALS:
    void itemIdsChanged();
    void historyMonthsChanged();
    void refreshMinutesChanged();
    void privacyModeChanged();
    void excludedCardIdsChanged();
    void credentialsRevisionChanged();
    void setupStepChanged();
    void itemNamesChanged();

private:
    explicit Config(QObject *parent = nullptr);
    void load();
    void write(const QString &key, const QVariant &value);
    void watch();
    void onFileChanged();

    QSettings m_settings;
    QFileSystemWatcher m_watcher;

    QStringList m_itemIds;
    int m_historyMonths = 12;
    int m_refreshMinutes = 60;
    bool m_privacyMode = false;
    QStringList m_excludedCardIds;
    int m_credentialsRevision = 0;
    int m_setupStep = 0;
    QHash<QString, QString> m_itemNames;
};
