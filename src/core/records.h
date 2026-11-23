// SPDX-License-Identifier: MIT
#pragma once

#include <QByteArray>
#include <QDate>
#include <QDateTime>
#include <QString>

// Plain records parsed from Pluggy JSON and stored in the local cache.

struct ItemRecord {
    QString id;
    QString connectorName;
    QString connectorImageUrl;
    QString status; // UPDATED, UPDATING, LOGIN_ERROR, OUTDATED, ...
    QString executionStatus;
    QString errorCode;
    QString errorMessage;
    QDateTime lastUpdatedAt;
    QDateTime consentExpiresAt;
    QDateTime nextAutoSyncAt;
    QByteArray raw;
};

struct AccountRecord {
    QString id;
    QString itemId;
    QString type; // BANK, CREDIT
    QString subtype; // CHECKING_ACCOUNT, SAVINGS_ACCOUNT, CREDIT_CARD, ...
    QString name;
    QString marketingName;
    QString number;
    QString owner;
    QString taxNumber; // CPF/CNPJ of the holder, digits only
    QString currency;
    double balance = 0;

    bool hasCredit = false;
    double creditLimit = 0;
    double availableCreditLimit = 0;
    double minimumPayment = 0;
    QDate closeDate;
    QDate dueDate;
    QString brand;
    QString level;
    QString holderType; // MAIN, ADDITIONAL
    QString creditStatus;

    QByteArray raw;
};

struct TransactionRecord {
    QString id;
    QString accountId;
    QDate date;
    QString description;
    double amount = 0; // as returned by Pluggy
    double normalizedAmount = 0; // negative = money going out (see PluggyParser::normalizedAmount)
    QString currency;
    QString category;
    QString categoryId;
    QString type; // DEBIT, CREDIT
    QString status; // POSTED, PENDING
    QString merchant;
    int installmentNumber = 0;
    int totalInstallments = 0;
    QString billId;
    // The other side of a PIX/TED: receiver for money going out, payer for
    // money coming in. Document is digits only.
    QString counterpartyName;
    QString counterpartyDocument;
};

struct BillRecord {
    QString id;
    QString accountId;
    QDate dueDate;
    QDate closingDate;
    double totalAmount = 0;
    double minimumPayment = 0;
    QString currency;
    QByteArray raw;
};

struct InvestmentRecord {
    QString id;
    QString itemId;
    QString name;
    QString code;
    QString type; // FIXED_INCOME, SECURITY, MUTUAL_FUND, EQUITY, ETF, COE, OTHER
    QString subtype;
    QString currency;
    QString status; // ACTIVE, PENDING, TOTAL_WITHDRAWAL
    QString institution;
    double balance = 0; // net of taxes and fees
    double amount = 0; // gross
    double amountProfit = 0;
    double annualRate = 0;
    double lastMonthRate = 0;
    double lastTwelveMonthsRate = 0;
    QDate date;
    QDate dueDate;
    QByteArray raw;
};

struct CategoryRecord {
    QString id;
    QString description;
    QString descriptionTranslated;
    QString parentId;
    QString parentDescription;
};
