// SPDX-License-Identifier: MIT
#pragma once

#include "records.h"
#include "saldocore_export.h"

#include <QJsonObject>
#include <QJsonValue>

// Turns Pluggy API JSON objects into records. Pure functions, unit-tested.
namespace PluggyParser
{
SALDOCORE_EXPORT QDate parseDate(const QJsonValue &value);
SALDOCORE_EXPORT QDateTime parseDateTime(const QJsonValue &value);

// Sign convention used everywhere in Saldo: negative = money going out,
// positive = money coming in. Pluggy reports credit card movements from the
// card's point of view (purchases positive, payments negative), so they are
// flipped. This is the only place that knows about it.
SALDOCORE_EXPORT double normalizedAmount(const QString &accountType, double amount);

// "123.456.789-00" → "12345678900"
SALDOCORE_EXPORT QString digitsOnly(const QString &text);

SALDOCORE_EXPORT ItemRecord parseItem(const QJsonObject &object);
SALDOCORE_EXPORT AccountRecord parseAccount(const QJsonObject &object);
SALDOCORE_EXPORT TransactionRecord parseTransaction(const QJsonObject &object, const QString &accountType);
SALDOCORE_EXPORT BillRecord parseBill(const QJsonObject &object, const QString &accountId);
SALDOCORE_EXPORT InvestmentRecord parseInvestment(const QJsonObject &object, const QString &itemId);
SALDOCORE_EXPORT CategoryRecord parseCategory(const QJsonObject &object);
}
