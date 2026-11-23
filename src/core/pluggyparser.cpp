// SPDX-License-Identifier: MIT
#include "pluggyparser.h"

#include <QJsonDocument>

using namespace Qt::StringLiterals;

namespace
{
QString text(const QJsonObject &object, QLatin1StringView key)
{
    const QJsonValue value = object.value(key);
    return value.isString() ? value.toString() : QString();
}

double number(const QJsonObject &object, QLatin1StringView key)
{
    const QJsonValue value = object.value(key);
    if (value.isString()) {
        return value.toString().toDouble();
    }
    return value.toDouble();
}

QByteArray compact(const QJsonObject &object)
{
    return QJsonDocument(object).toJson(QJsonDocument::Compact);
}
}

QDate PluggyParser::parseDate(const QJsonValue &value)
{
    // Dates come as "2026-11-21T00:00:00.000Z". Only the calendar day matters;
    // converting to local time would move it to the previous day in Brazil.
    const QString s = value.toString();
    if (s.size() < 10) {
        return {};
    }
    return QDate::fromString(s.left(10), Qt::ISODate);
}

QDateTime PluggyParser::parseDateTime(const QJsonValue &value)
{
    const QString s = value.toString();
    if (s.isEmpty()) {
        return {};
    }
    QDateTime dt = QDateTime::fromString(s, Qt::ISODateWithMs);
    if (!dt.isValid()) {
        dt = QDateTime::fromString(s, Qt::ISODate);
    }
    return dt;
}

double PluggyParser::normalizedAmount(const QString &accountType, double amount)
{
    if (accountType == "CREDIT"_L1) {
        return -amount;
    }
    return amount;
}

QString PluggyParser::digitsOnly(const QString &text)
{
    QString digits;
    for (const QChar c : text) {
        if (c.isDigit()) {
            digits.append(c);
        }
    }
    return digits;
}

ItemRecord PluggyParser::parseItem(const QJsonObject &object)
{
    ItemRecord r;
    r.id = text(object, "id"_L1);
    const QJsonObject connector = object.value("connector"_L1).toObject();
    r.connectorName = text(connector, "name"_L1);
    r.connectorImageUrl = text(connector, "imageUrl"_L1);
    r.status = text(object, "status"_L1);
    r.executionStatus = text(object, "executionStatus"_L1);
    const QJsonObject error = object.value("error"_L1).toObject();
    r.errorCode = text(error, "code"_L1);
    r.errorMessage = text(error, "message"_L1);
    r.lastUpdatedAt = parseDateTime(object.value("lastUpdatedAt"_L1));
    r.consentExpiresAt = parseDateTime(object.value("consentExpiresAt"_L1));
    r.nextAutoSyncAt = parseDateTime(object.value("nextAutoSyncAt"_L1));
    r.raw = compact(object);
    return r;
}

AccountRecord PluggyParser::parseAccount(const QJsonObject &object)
{
    AccountRecord r;
    r.id = text(object, "id"_L1);
    r.itemId = text(object, "itemId"_L1);
    r.type = text(object, "type"_L1);
    r.subtype = text(object, "subtype"_L1);
    r.name = text(object, "name"_L1);
    r.marketingName = text(object, "marketingName"_L1);
    r.number = text(object, "number"_L1);
    r.owner = text(object, "owner"_L1);
    r.taxNumber = digitsOnly(text(object, "taxNumber"_L1));
    r.currency = text(object, "currencyCode"_L1);
    if (r.currency.isEmpty()) {
        r.currency = u"BRL"_s;
    }
    r.balance = number(object, "balance"_L1);

    const QJsonObject credit = object.value("creditData"_L1).toObject();
    if (!credit.isEmpty()) {
        r.hasCredit = true;
        r.creditLimit = number(credit, "creditLimit"_L1);
        r.availableCreditLimit = number(credit, "availableCreditLimit"_L1);
        r.minimumPayment = number(credit, "minimumPayment"_L1);
        r.closeDate = parseDate(credit.value("balanceCloseDate"_L1));
        r.dueDate = parseDate(credit.value("balanceDueDate"_L1));
        r.brand = text(credit, "brand"_L1);
        r.level = text(credit, "level"_L1);
        r.holderType = text(credit, "holderType"_L1);
        r.creditStatus = text(credit, "status"_L1);
    }
    r.raw = compact(object);
    return r;
}

TransactionRecord PluggyParser::parseTransaction(const QJsonObject &object, const QString &accountType)
{
    TransactionRecord r;
    r.id = text(object, "id"_L1);
    r.accountId = text(object, "accountId"_L1);
    r.date = parseDate(object.value("date"_L1));
    r.description = text(object, "description"_L1);
    if (r.description.isEmpty()) {
        r.description = text(object, "descriptionRaw"_L1);
    }
    r.currency = text(object, "currencyCode"_L1);
    r.amount = number(object, "amount"_L1);

    // Foreign-currency movements carry the converted value as well; totals
    // must use the account currency.
    const QJsonValue converted = object.value("amountInAccountCurrency"_L1);
    if (converted.isDouble()) {
        r.amount = converted.toDouble();
        r.currency = QString();
    }
    if (r.currency.isEmpty()) {
        r.currency = u"BRL"_s;
    }
    r.normalizedAmount = normalizedAmount(accountType, r.amount);

    r.category = text(object, "category"_L1);
    r.categoryId = text(object, "categoryId"_L1);
    r.type = text(object, "type"_L1);
    r.status = text(object, "status"_L1);

    const QJsonObject merchant = object.value("merchant"_L1).toObject();
    r.merchant = text(merchant, "name"_L1);
    if (r.merchant.isEmpty()) {
        r.merchant = text(merchant, "businessName"_L1);
    }

    const QJsonObject card = object.value("creditCardMetadata"_L1).toObject();
    r.installmentNumber = card.value("installmentNumber"_L1).toInt();
    r.totalInstallments = card.value("totalInstallments"_L1).toInt();
    r.billId = text(card, "billId"_L1);

    const QJsonObject payment = object.value("paymentData"_L1).toObject();
    const QJsonObject other = payment.value(r.normalizedAmount < 0 ? "receiver"_L1 : "payer"_L1).toObject();
    r.counterpartyName = text(other, "name"_L1);
    const QJsonValue document = other.value("documentNumber"_L1);
    r.counterpartyDocument = digitsOnly(document.isObject() ? text(document.toObject(), "value"_L1) : document.toString());
    return r;
}

BillRecord PluggyParser::parseBill(const QJsonObject &object, const QString &accountId)
{
    BillRecord r;
    r.id = text(object, "id"_L1);
    r.accountId = accountId;
    r.dueDate = parseDate(object.value("dueDate"_L1));
    r.closingDate = parseDate(object.value("billClosingDate"_L1));
    r.totalAmount = number(object, "totalAmount"_L1);
    r.minimumPayment = number(object, "minimumPaymentAmount"_L1);
    r.currency = text(object, "totalAmountCurrencyCode"_L1);
    if (r.currency.isEmpty()) {
        r.currency = u"BRL"_s;
    }
    r.raw = compact(object);
    return r;
}

InvestmentRecord PluggyParser::parseInvestment(const QJsonObject &object, const QString &itemId)
{
    InvestmentRecord r;
    r.id = text(object, "id"_L1);
    r.itemId = itemId;
    r.name = text(object, "name"_L1);
    r.code = text(object, "code"_L1);
    r.type = text(object, "type"_L1);
    r.subtype = text(object, "subtype"_L1);
    r.currency = text(object, "currencyCode"_L1);
    if (r.currency.isEmpty()) {
        r.currency = u"BRL"_s;
    }
    r.status = text(object, "status"_L1);
    const QJsonValue institution = object.value("institution"_L1);
    r.institution = institution.isObject() ? text(institution.toObject(), "name"_L1) : institution.toString();
    r.balance = number(object, "balance"_L1);
    r.amount = number(object, "amount"_L1);
    r.amountProfit = number(object, "amountProfit"_L1);
    r.annualRate = number(object, "annualRate"_L1);
    r.lastMonthRate = number(object, "lastMonthRate"_L1);
    r.lastTwelveMonthsRate = number(object, "lastTwelveMonthsRate"_L1);
    r.date = parseDate(object.value("date"_L1));
    r.dueDate = parseDate(object.value("dueDate"_L1));
    r.raw = compact(object);
    return r;
}

CategoryRecord PluggyParser::parseCategory(const QJsonObject &object)
{
    CategoryRecord r;
    r.id = text(object, "id"_L1);
    r.description = text(object, "description"_L1);
    r.descriptionTranslated = text(object, "descriptionTranslated"_L1);
    r.parentId = text(object, "parentId"_L1);
    r.parentDescription = text(object, "parentDescription"_L1);
    return r;
}
