// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QObject>
#include <QQmlEngine>

// Lets the Plasma widget open the full app (optionally on a given page).
class SALDOCORE_EXPORT Launcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool canOpenApp READ canOpenApp CONSTANT)

public:
    explicit Launcher(QObject *parent = nullptr);

    bool canOpenApp() const;

    // page: overview, accounts, cards, transactions, investments, settings, setup, about
    Q_INVOKABLE bool openApp(const QString &page = QString()) const;
};
