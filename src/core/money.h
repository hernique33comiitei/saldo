// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QDate>
#include <QDateTime>
#include <QLocale>
#include <QObject>
#include <QQmlEngine>

// Formatting helpers for money, percentages and dates (C++ and QML).
namespace MoneyFormat
{
SALDOCORE_EXPORT QString format(double value, const QString &currency = QStringLiteral("BRL"));
SALDOCORE_EXPORT QString formatSigned(double value, const QString &currency = QStringLiteral("BRL"));
SALDOCORE_EXPORT QString compact(double value, const QString &currency = QStringLiteral("BRL"));
// Chart axis label: the unit (thousands, millions) and decimals follow the
// axis step, so every label of one axis reads the same way ("R$ 5K", "R$ 10K").
SALDOCORE_EXPORT QString axisLabel(double value, double step, const QString &currency = QStringLiteral("BRL"));
SALDOCORE_EXPORT QString percent(double ratio);
SALDOCORE_EXPORT QString number(double value, int decimals); // "12,3"
SALDOCORE_EXPORT QString relativeTime(const QDateTime &when);
// Dates: the numbers are always in the Brazilian order (dd/MM/yyyy), like the
// money (the app only works with Brazilian banks); month and day names follow
// the app's language. Never QLocale::system(): a phone set to English (US)
// showed 11/30/26 and "November de 2026" with the app in Portuguese.
SALDOCORE_EXPORT QLocale uiLocale(); // the app's language (Settings or the system's)
SALDOCORE_EXPORT QString shortDate(const QDate &date);
// Short date without the year ("22/11"), for chart axes.
SALDOCORE_EXPORT QString dayMonth(const QDate &date);
SALDOCORE_EXPORT QString dayLabel(const QDate &date);
SALDOCORE_EXPORT QString monthLabel(const QDate &month);
SALDOCORE_EXPORT QString shortMonthLabel(const QDate &month);
}

class SALDOCORE_EXPORT Money : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString masked READ masked CONSTANT)

public:
    explicit Money(QObject *parent = nullptr);

    QString masked() const;

    Q_INVOKABLE QString format(double value, const QString &currency = QStringLiteral("BRL")) const;
    Q_INVOKABLE QString formatSigned(double value, const QString &currency = QStringLiteral("BRL")) const;
    Q_INVOKABLE QString compact(double value, const QString &currency = QStringLiteral("BRL")) const;
    Q_INVOKABLE QString axisLabel(double value, double step, const QString &currency = QStringLiteral("BRL")) const;
    Q_INVOKABLE QString percent(double ratio) const;
    Q_INVOKABLE QString number(double value, int decimals = 0) const;
    Q_INVOKABLE QString relativeTime(const QDateTime &when) const;
    Q_INVOKABLE QString shortDate(const QDate &date) const;
    Q_INVOKABLE QString dayMonth(const QDate &date) const;
};
