// SPDX-License-Identifier: MIT
#include "cardbills.h"
#include "cardtotals.h"
#include "categories.h"
#include "config.h"
#include "database.h"
#include "financesummary.h"
#include "money.h"
#include "paths.h"
#include "pluggyparser.h"
#include "accountsmodel.h"
#include "balancehistorymodel.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTest>

using namespace Qt::StringLiterals;

class CoreTest : public QObject
{
    Q_OBJECT

private:
    static QJsonObject fixture(const QString &name)
    {
        QFile file(QStringLiteral(FIXTURES_DIR) + u'/' + name);
        if (!file.open(QIODevice::ReadOnly)) {
            qFatal("missing fixture");
        }
        return QJsonDocument::fromJson(file.readAll()).object();
    }

    static QList<AccountRecord> accounts()
    {
        QList<AccountRecord> list;
        const QJsonArray results = fixture(u"accounts.json"_s).value("results"_L1).toArray();
        for (const QJsonValue &value : results) {
            list.append(PluggyParser::parseAccount(value.toObject()));
        }
        return list;
    }

    static QList<TransactionRecord> transactions()
    {
        QList<TransactionRecord> list;
        const QJsonArray results = fixture(u"transactions_v2.json"_s).value("results"_L1).toArray();
        for (const QJsonValue &value : results) {
            list.append(PluggyParser::parseTransaction(value.toObject(), u"CREDIT"_s));
        }
        return list;
    }

    QTemporaryDir m_dir;

private Q_SLOTS:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        Paths::setOverrideDir(m_dir.path());
    }

    void parseItem()
    {
        const ItemRecord item = PluggyParser::parseItem(fixture(u"item.json"_s));
        QCOMPARE(item.id, u"3fa85f64-5717-4562-b3fc-2c963f66afa6"_s);
        QCOMPARE(item.connectorName, u"MeuPluggy"_s);
        QCOMPARE(item.status, u"UPDATED"_s);
        QVERIFY(item.errorCode.isEmpty());
        QCOMPARE(item.lastUpdatedAt, QDateTime(QDate(2026, 11, 21), QTime(9, 15), QTimeZone::UTC));
        QVERIFY(item.consentExpiresAt.isValid());
    }

    void axisLabels()
    {
        // The unit and decimals follow the step, so one axis reads alike.
        // (Translated: "R$ 20K" in English, "R$ 20 mil" in Portuguese.)
        const QString thousands = MoneyFormat::axisLabel(20000, 5000);
        QVERIFY2(thousands.startsWith(u"R$"_s) && thousands.contains(u"20"_s) && !thousands.contains(u','), qPrintable(thousands));
        const QString five = MoneyFormat::axisLabel(5000, 5000);
        QVERIFY2(five.contains(u'5') && !five.contains(u"5.000"_s) && !five.contains(u','), qPrintable(five));
        // Millions only when the step is in millions: a 500K step stays in thousands.
        const QString millions = MoneyFormat::axisLabel(3000000, 1000000);
        QVERIFY2(millions.contains(u'3') && !millions.contains(u"000"_s), qPrintable(millions));
        const QString halfMillions = MoneyFormat::axisLabel(1500000, 500000);
        QVERIFY2(halfMillions.contains(u"1.500"_s), qPrintable(halfMillions));
        const QString zero = MoneyFormat::axisLabel(0, 5000);
        QVERIFY2(!zero.contains(u'K') && zero.contains(u'0'), qPrintable(zero));
        const QString small = MoneyFormat::axisLabel(23600, 100);
        QVERIFY2(small.contains(u"23.600"_s) && !small.contains(u'K'), qPrintable(small));
    }

    void dayMonthLabels()
    {
        // Chart axes: the short date without the year, whatever the locale.
        // ("22/11" in pt_BR, "11/22" in en_US, "22 Nov" in the C locale.)
        const QString label = MoneyFormat::dayMonth(QDate(2026, 11, 22));
        QVERIFY2(label.contains(u"22"_s) && !label.contains(u"26"_s), qPrintable(label));
        QVERIFY(MoneyFormat::dayMonth(QDate()).isEmpty());
    }

    void languagePreference()
    {
        Config *config = Config::instance();
        config->setLanguage(u"pt_BR"_s);
        QCOMPARE(config->language(), u"pt_BR"_s);
        QCOMPARE(Config::storedLanguage(), u"pt_BR"_s); // what main.cpp reads at startup
        config->setLanguage(u"xx"_s); // not offered: ignored
        QCOMPARE(config->language(), u"pt_BR"_s);
        config->setLanguage(QString());
        QVERIFY(Config::storedLanguage().isEmpty());
    }

    void parseAccounts()
    {
        const QList<AccountRecord> list = accounts();
        QCOMPARE(list.size(), 3);

        const AccountRecord &checking = list.at(0);
        QCOMPARE(checking.type, u"BANK"_s);
        QCOMPARE(checking.marketingName, u"Conta Digital"_s);
        QCOMPARE(checking.balance, 1520.75);
        QCOMPARE(checking.taxNumber, u"00000000000"_s);
        QVERIFY(!checking.hasCredit);

        const AccountRecord &card = list.at(1);
        QVERIFY(card.hasCredit);
        QCOMPARE(card.creditLimit, 10000.0);
        QCOMPARE(card.availableCreditLimit, 7900.0);
        QCOMPARE(card.minimumPayment, 315.06);
        QCOMPARE(card.brand, u"MASTERCARD"_s);
        // Calendar day must not shift with the local time zone.
        QCOMPARE(card.dueDate, QDate(2026, 12, 10));
        QCOMPARE(card.closeDate, QDate(2026, 12, 3));
    }

    void parseTransactions()
    {
        const QList<TransactionRecord> list = transactions();
        QCOMPARE(list.size(), 3);

        // Card purchase: positive at Pluggy, money going out for the user.
        QCOMPARE(list.at(0).amount, 159.2);
        QCOMPARE(list.at(0).normalizedAmount, -159.2);
        QCOMPARE(list.at(0).date, QDate(2026, 11, 15));
        QCOMPARE(list.at(0).installmentNumber, 2);
        QCOMPARE(list.at(0).totalInstallments, 6);
        QCOMPARE(list.at(0).merchant, u"Exemplo Supermercados"_s);
        QCOMPARE(list.at(0).billId, u"bill-1"_s);

        // Card payment: negative at Pluggy, positive for the card.
        QCOMPARE(list.at(1).normalizedAmount, 1800.0);

        // Foreign currency: the converted amount is used.
        QCOMPARE(list.at(2).amount, 112.5);
        QCOMPARE(list.at(2).currency, u"BRL"_s);
        QCOMPARE(list.at(2).status, u"PENDING"_s);

        // Bank accounts keep Pluggy's sign.
        QCOMPARE(PluggyParser::normalizedAmount(u"BANK"_s, -50.0), -50.0);
    }

    void cardTotalsSkipSharedLimits()
    {
        const QList<CardLimitRow> cards = {
            {u"main"_s, u"item"_s, u"MAIN"_s, 10000, 7900},
            {u"virtual"_s, u"item"_s, u"MAIN"_s, 10000, 7900}, // same limit, same connection
            {u"extra"_s, u"item"_s, u"ADDITIONAL"_s, 10000, 7900},
            {u"other"_s, u"item2"_s, u"MAIN"_s, 5000, 5000},
        };
        CardTotals totals = computeCardTotals(cards, {});
        QCOMPARE(totals.limit, 15000.0);
        QCOMPARE(totals.used, 2100.0);
        QCOMPARE(totals.available, 12900.0);
        QVERIFY(totals.shared.contains(u"virtual"_s));
        QVERIFY(totals.shared.contains(u"extra"_s));

        totals = computeCardTotals(cards, {u"other"_s});
        QCOMPARE(totals.limit, 10000.0);
        QCOMPARE(totals.usedRatio(), 0.21);
    }

    void categories()
    {
        QCOMPARE(Categories::iconName(u"Groceries"_s), u"food"_s);
        QCOMPARE(Categories::iconName(u"Healthcare"_s), u"love"_s);
        QCOMPARE(Categories::iconName(u"Credit card payment"_s), u"view-financial-account-credit-card-symbolic"_s);
        QCOMPARE(Categories::iconName(QString()), u"tag-symbolic"_s);
        QCOMPARE(Categories::displayName(QString(), QString()).isEmpty(), false);
    }

    void itemIdValidation()
    {
        QVERIFY(Config::isValidItemId(u"3fa85f64-5717-4562-b3fc-2c963f66afa6"_s));
        QVERIFY(Config::isValidItemId(u" 3FA85F64-5717-4562-B3FC-2C963F66AFA6 "_s));
        QVERIFY(!Config::isValidItemId(u"not-an-id"_s));
        QVERIFY(!Config::isValidItemId(u"id: 3fa85f64-5717-4562-b3fc-2c963f66afa6"_s));

        // Pasting a whole line, or several items at once, keeps only the IDs.
        const QStringList ids = Config::findIds(u"Itens Conectados\n3FA85F64-5717-4562-B3FC-2C963F66AFA6  MeuPluggy\n"
                                                "0f9c2f5e-3c1a-4d1e-9a51-6f7d1b8e4a01 3fa85f64-5717-4562-b3fc-2c963f66afa6"_s);
        QCOMPARE(ids, (QStringList{u"3fa85f64-5717-4562-b3fc-2c963f66afa6"_s, u"0f9c2f5e-3c1a-4d1e-9a51-6f7d1b8e4a01"_s}));
        QVERIFY(Config::findIds(u"pluggy_sk_abc"_s).isEmpty());
    }

    void connectionNames()
    {
        Config *config = Config::instance();
        const QString id = u"3fa85f64-5717-4562-b3fc-2c963f66afa6"_s;
        // Meu Pluggy items are all called "MeuPluggy": fall back to the id.
        QVERIFY(config->displayItemName(id, u"MeuPluggy"_s).endsWith(u"3fa8"_s));
        QCOMPARE(config->displayItemName(id, u"Banco Exemplo"_s), u"Banco Exemplo"_s);
        config->setItemName(id, u"  Nubank "_s);
        QCOMPARE(config->itemName(id), u"Nubank"_s);
        QCOMPARE(config->displayItemName(id, u"MeuPluggy"_s), u"Nubank"_s);
        config->setItemName(id, QString());
        QVERIFY(config->itemName(id).isEmpty());
    }

    void databaseReconcileWindow()
    {
        const QString item = u"3fa85f64-5717-4562-b3fc-2c963f66afa6"_s;
        QVERIFY(Database::upsertItem(PluggyParser::parseItem(fixture(u"item.json"_s))));
        QVERIFY(Database::replaceAccounts(item, accounts()));
        QVERIFY(Database::replaceTransactions(u"acc-card-main"_s, QDate(), transactions()));

        auto count = [](const QString &where) {
            QSqlQuery q(Database::connection());
            q.exec(u"SELECT COUNT(*) FROM transactions WHERE "_s + where);
            return q.next() ? q.value(0).toInt() : -1;
        };
        QCOMPARE(count(u"1 = 1"_s), 3);

        // Re-sync from Nov 12: tx-3 (pending) vanished upstream, tx-1 is kept,
        // tx-2 (Nov 10) is outside the window and must survive.
        QList<TransactionRecord> window = transactions();
        window.removeAt(2);
        window.removeAt(1);
        QVERIFY(Database::replaceTransactions(u"acc-card-main"_s, QDate(2026, 11, 12), window));
        QCOMPARE(count(u"1 = 1"_s), 2);
        QCOMPARE(count(u"id = 'tx-3'"_s), 0);
        QCOMPARE(count(u"id = 'tx-2'"_s), 1);

        // An account that disappears takes its transactions with it.
        QList<AccountRecord> remaining = accounts();
        remaining.removeAt(1);
        QVERIFY(Database::replaceAccounts(item, remaining));
        QCOMPARE(count(u"account_id = 'acc-card-main'"_s), 0);
    }

    void summaryTotals()
    {
        const QString item = u"3fa85f64-5717-4562-b3fc-2c963f66afa6"_s;
        Config::instance()->setItemIds({item});
        QVERIFY(Database::replaceAccounts(item, accounts()));

        const QDate today = QDate::currentDate();
        QList<TransactionRecord> list = transactions();
        for (TransactionRecord &t : list) {
            t.date = today;
        }
        QVERIFY(Database::replaceTransactions(u"acc-card-main"_s, QDate(), list));

        QVERIFY(Database::detectInternalTransfers()); // the card payment is internal
        FinanceSummary *summary = FinanceSummary::instance();
        summary->reload();
        QCOMPARE(summary->totalCash(), 1520.75);
        QCOMPARE(summary->cardLimit(), 10000.0); // the virtual card shares the limit
        QCOMPARE(summary->cardUsed(), 2100.0);
        // The card payment is an internal movement: not income.
        QCOMPARE(summary->monthIncome(), 0.0);
        QCOMPARE(summary->monthExpenses(), 159.2 + 112.5);
        QCOMPARE(summary->connectionCount(), 1);
        QVERIFY(summary->hasData());
    }

    void internalTransfers()
    {
        QVERIFY(Database::clearAll());
        const QDate today = QDate::currentDate();
        const QDate d1 = QDate(today.year(), today.month(), 1);

        auto account = [](const QString &id, const QString &type, const QString &taxNumber) {
            AccountRecord a;
            a.id = id;
            a.itemId = u"item-x"_s;
            a.type = type;
            a.taxNumber = taxNumber;
            a.currency = u"BRL"_s;
            return a;
        };
        QVERIFY(Database::replaceAccounts(u"item-x"_s,
                                          {account(u"inter"_s, u"BANK"_s, u"11111111111"_s),
                                           account(u"btg"_s, u"BANK"_s, u"22222222000199"_s),
                                           account(u"card"_s, u"CREDIT"_s, QString())}));

        auto tx = [](const QString &id, const QString &accountType, const QDate &date, const QString &category, double normalized,
                     const QString &document = QString()) {
            TransactionRecord t;
            t.id = id;
            t.date = date;
            t.category = category;
            t.normalizedAmount = normalized;
            t.amount = accountType == "CREDIT"_L1 ? -normalized : normalized;
            t.counterpartyDocument = document;
            return t;
        };
        // inter: 5k PIX to BTG (own, other document), PIX to a friend, PIX to
        // own CPF elsewhere, card bill paid with a generic "Transfers", salary
        // and a taxi ride that happens to match a reimbursement on BTG.
        QVERIFY(Database::replaceTransactions(u"inter"_s,
                                              QDate(),
                                              {tx(u"pix-to-btg"_s, u"BANK"_s, d1, u"Transfer - PIX"_s, -5000),
                                               tx(u"pix-friend"_s, u"BANK"_s, d1, u"Transfer - PIX"_s, -50, u"99999999999"_s),
                                               tx(u"pix-own-cpf"_s, u"BANK"_s, d1, u"Transfer - PIX"_s, -200, u"11111111111"_s),
                                               tx(u"bill"_s, u"BANK"_s, d1.addDays(4), u"Transfers"_s, -300),
                                               tx(u"salary"_s, u"BANK"_s, d1, u"Salary"_s, 1000),
                                               tx(u"taxi"_s, u"BANK"_s, d1, u"Taxi and ride-hailing"_s, -80)}));
        // btg: receives the 5k, pays a 5k bill, gets the taxi money back.
        QVERIFY(Database::replaceTransactions(u"btg"_s,
                                              QDate(),
                                              {tx(u"pix-from-inter"_s, u"BANK"_s, d1.addDays(1), u"Transfer - PIX"_s, 5000),
                                               tx(u"boleto"_s, u"BANK"_s, d1.addDays(2), u"Bills"_s, -5000),
                                               tx(u"taxi-back"_s, u"BANK"_s, d1, u"Taxi and ride-hailing"_s, 80)}));
        // card: a purchase, the bill payment (Pluggy says "Shopping") and a refund.
        QVERIFY(Database::replaceTransactions(u"card"_s,
                                              QDate(),
                                              {tx(u"groceries"_s, u"CREDIT"_s, d1, u"Groceries"_s, -100),
                                               tx(u"payment"_s, u"CREDIT"_s, d1.addDays(5), u"Shopping"_s, 300),
                                               tx(u"refund"_s, u"CREDIT"_s, d1.addDays(2), u"Shopping"_s, 20)}));

        QVERIFY(Database::detectInternalTransfers());
        auto internal = [](const QString &id) {
            QSqlQuery q(Database::connection());
            q.prepare(u"SELECT internal, internal_reason FROM transactions WHERE id = ?"_s);
            q.addBindValue(id);
            q.exec();
            return q.next() ? std::make_pair(q.value(0).toInt(), q.value(1).toString()) : std::make_pair(-1, QString());
        };
        QCOMPARE(internal(u"pix-to-btg"_s), std::make_pair(1, u"pair"_s));
        QCOMPARE(internal(u"pix-from-inter"_s), std::make_pair(1, u"pair"_s));
        QCOMPARE(internal(u"pix-own-cpf"_s), std::make_pair(1, u"document"_s));
        QCOMPARE(internal(u"bill"_s), std::make_pair(1, u"card-payment"_s));
        QCOMPARE(internal(u"payment"_s), std::make_pair(1, u"card-payment"_s));
        QCOMPARE(internal(u"pix-friend"_s).first, 0);
        QCOMPARE(internal(u"boleto"_s).first, 0);
        QCOMPARE(internal(u"refund"_s).first, 0);
        // Same amount, but not transfers: a coincidence, not a pair.
        QCOMPARE(internal(u"taxi"_s).first, 0);
        QCOMPARE(internal(u"taxi-back"_s).first, 0);

        // The user's example: 5k moved Inter → BTG, then a 5k bill paid on BTG
        // is 5k of expenses, not 10k.
        FinanceSummary *summary = FinanceSummary::instance();
        summary->reload();
        // income: salary 1000 + taxi money back 80 (card money is never income)
        QCOMPARE(summary->monthIncome(), 1080.0);
        // expenses: friend 50 + boleto 5000 + taxi 80 + groceries 100 - refund 20
        QCOMPARE(summary->monthExpenses(), 5210.0);

        // Manual overrides win, and can be undone.
        QVERIFY(Database::setInternalOverride(u"pix-friend"_s, 1));
        QCOMPARE(internal(u"pix-friend"_s), std::make_pair(1, u"manual"_s));
        QVERIFY(Database::setInternalOverride(u"pix-to-btg"_s, 0));
        QCOMPARE(internal(u"pix-to-btg"_s), std::make_pair(0, u"manual-counted"_s));
        QVERIFY(Database::setInternalOverride(u"pix-friend"_s, -1));
        QVERIFY(Database::setInternalOverride(u"pix-to-btg"_s, -1));
        QCOMPARE(internal(u"pix-friend"_s).first, 0);
        QCOMPARE(internal(u"pix-to-btg"_s), std::make_pair(1, u"pair"_s));

        // Overrides survive a cache wipe (they are the user's decisions).
        QVERIFY(Database::setInternalOverride(u"boleto"_s, 1));
        QVERIFY(Database::clearAll());
        QSqlQuery q(Database::connection());
        q.exec(u"SELECT COUNT(*) FROM transaction_overrides WHERE id = 'boleto'"_s);
        QVERIFY(q.next());
        QCOMPARE(q.value(0).toInt(), 1);
        QVERIFY(Database::setInternalOverride(u"boleto"_s, -1));
    }

    void balanceSnapshots()
    {
        QVERIFY(Database::clearAll());
        AccountRecord bank;
        bank.id = u"snap-bank"_s;
        bank.itemId = u"item-s"_s;
        bank.type = u"BANK"_s;
        bank.balance = 100;
        QVERIFY(Database::replaceAccounts(u"item-s"_s, {bank}));
        const QDate today = QDate::currentDate();
        QVERIFY(Database::recordBalanceSnapshot(today.addDays(-1)));
        bank.balance = 250;
        QVERIFY(Database::replaceAccounts(u"item-s"_s, {bank}));
        QVERIFY(Database::recordBalanceSnapshot(today));

        BalanceHistoryModel model;
        model.reload();
        QCOMPARE(model.count(), 2);
        QCOMPARE(model.get(0).value(u"total"_s).toDouble(), 100.0);
        QCOMPARE(model.get(1).value(u"total"_s).toDouble(), 250.0);
        QCOMPARE(model.minValue(), 100.0);
        QCOMPARE(model.maxValue(), 250.0);
    }

    void cardBills()
    {
        QVERIFY(Database::clearAll());
        const QDate today = QDate::currentDate();
        const QDate lastClosing = today.addDays(-20);
        const QDate lastDue = today.addDays(-13);

        AccountRecord card;
        card.id = u"gold"_s;
        card.itemId = u"item-c"_s;
        card.type = u"CREDIT"_s;
        card.creditLimit = 5000;
        card.availableCreditLimit = 1800.0;
        card.balance = 3200.0; // whole debt, future installments included
        card.closeDate = lastClosing;
        card.dueDate = lastDue;
        QVERIFY(Database::replaceAccounts(u"item-c"_s, {card}));

        BillRecord closed;
        closed.id = u"bill-nov"_s;
        closed.accountId = card.id;
        closed.closingDate = lastClosing;
        closed.dueDate = lastDue;
        closed.totalAmount = 1500.5;
        QVERIFY(Database::replaceBills(card.id, {closed}));

        auto tx = [](const QString &id, const QDate &date, double normalized, const QString &billId, const QString &category = QString()) {
            TransactionRecord t;
            t.id = id;
            t.date = date;
            t.normalizedAmount = normalized;
            t.billId = billId;
            t.category = category;
            return t;
        };
        QVERIFY(Database::replaceTransactions(card.id,
                                              QDate(),
                                              {tx(u"old-purchase"_s, lastClosing.addDays(-5), -1500.5, u"bill-nov"_s),
                                               tx(u"new-purchase"_s, today.addDays(-3), -900.1, QString()),
                                               // installment 7/10 of an April purchase: old date, open bill
                                               tx(u"installment"_s, today.addMonths(-7), -410.25, QString()),
                                               tx(u"refund"_s, today.addDays(-2), 20, QString(), u"Shopping"_s),
                                               tx(u"payment"_s, lastDue, 1500.5, QString(), u"Credit card payment"_s)}));
        QVERIFY(Database::detectInternalTransfers());

        CardBill bill = computeCardBill(card.id, card.closeDate, card.dueDate);
        QVERIFY(bill.known);
        QCOMPARE(bill.open, 900.1 + 410.25 - 20);
        QCOMPARE(bill.closedToPay, 0.0); // due date passed
        QVERIFY(bill.lastPaid());
        QVERIFY(!bill.lastOverdue());
        QCOMPARE(bill.lastTotal, 1500.5);
        QCOMPARE(bill.openClosing, lastClosing.addMonths(1));
        QCOMPARE(bill.openDue, lastDue.addMonths(1));
        QCOMPARE(bill.toPay(), bill.open);

        FinanceSummary *summary = FinanceSummary::instance();
        summary->reload();
        QCOMPARE(summary->nextBills(), 900.1 + 410.25 - 20);
        QCOMPARE(summary->nextBillDue(), lastDue.addMonths(1));

        // A closed bill that is not due yet, half paid: what is left is to pay too.
        closed.closingDate = today.addDays(-4);
        closed.dueDate = today.addDays(3);
        closed.totalAmount = 1000;
        QVERIFY(Database::replaceBills(card.id, {closed}));
        QVERIFY(Database::replaceTransactions(card.id,
                                              QDate(),
                                              {tx(u"billed"_s, today.addDays(-10), -1000, u"bill-nov"_s),
                                               tx(u"open"_s, today.addDays(-1), -50, QString()),
                                               tx(u"half-payment"_s, today.addDays(-1), 400, QString(), u"Credit card payment"_s)}));
        QVERIFY(Database::detectInternalTransfers());
        bill = computeCardBill(card.id, QDate(), QDate());
        QCOMPARE(bill.closedToPay, 600.0);
        QCOMPARE(bill.open, 50.0);
        QCOMPARE(bill.nextDue(), today.addDays(3));
        QCOMPARE(bill.toPay(), 650.0);
        QVERIFY(!bill.lastPaid());
        QVERIFY(!bill.lastOverdue());

        // Due date passed and no payment showed up: flagged, but not added to
        // what is to pay next (Pluggy may simply not list the payment).
        closed.closingDate = today.addDays(-12);
        closed.dueDate = today.addDays(-5);
        QVERIFY(Database::replaceBills(card.id, {closed}));
        QVERIFY(Database::replaceTransactions(card.id, QDate(), {tx(u"billed"_s, today.addDays(-20), -1000, u"bill-nov"_s), tx(u"open"_s, today.addDays(-1), -50, QString())}));
        QVERIFY(Database::detectInternalTransfers());
        bill = computeCardBill(card.id, QDate(), QDate());
        QVERIFY(bill.lastOverdue());
        QCOMPARE(bill.lastUnpaid, 1000.0);
        QCOMPARE(bill.closedToPay, 0.0);
        QCOMPARE(bill.toPay(), 50.0);

        // No bills and no billIds at all: fall back to the creditData closing date.
        QVERIFY(Database::replaceBills(card.id, {}));
        QVERIFY(Database::replaceTransactions(card.id, QDate(), {tx(u"a"_s, today.addDays(-30), -70, QString()), tx(u"b"_s, today.addDays(-2), -30, QString())}));
        bill = computeCardBill(card.id, today.addDays(-10), today.addDays(-3));
        QVERIFY(bill.known);
        QCOMPARE(bill.open, 30.0);
    }

    void repairsInconsistentSchema()
    {
        // What happened during an update: user_version says 2, but an old
        // plasmashell recreated "transactions" without the new columns.
        {
            QSqlDatabase raw = QSqlDatabase::addDatabase(u"QSQLITE"_s, u"sabotage"_s);
            raw.setDatabaseName(Paths::databaseFile());
            QVERIFY(raw.open());
            QSqlQuery q(raw);
            QVERIFY(q.exec(u"DROP TABLE transactions"_s));
            QVERIFY(q.exec(u"CREATE TABLE transactions (id TEXT PRIMARY KEY, account_id TEXT NOT NULL, date TEXT, amount REAL)"_s));
            q.finish();
            raw.close();
        }
        QSqlDatabase::removeDatabase(u"sabotage"_s);

        Database::closeThreadConnection();
        QSqlQuery columns(Database::connection()); // reopening runs the schema check
        QVERIFY(columns.exec(u"PRAGMA table_info(transactions)"_s));
        bool hasInternal = false;
        while (columns.next()) {
            hasInternal |= columns.value(1).toString() == "internal"_L1;
        }
        QVERIFY(hasInternal);

        TransactionRecord t;
        t.id = u"after-repair"_s;
        t.date = QDate::currentDate();
        QVERIFY(Database::replaceTransactions(u"some-account"_s, QDate(), {t}));
    }

    void accountsModelFilter()
    {
        QVERIFY(Database::clearAll());
        AccountRecord bank;
        bank.id = u"bank-1"_s;
        bank.itemId = u"item-a"_s;
        bank.type = u"BANK"_s;
        bank.name = u"Conta"_s;
        bank.raw = R"({"id":"bank-1"})";
        AccountRecord card;
        card.id = u"card-1"_s;
        card.itemId = u"item-a"_s;
        card.type = u"CREDIT"_s;
        card.name = u"Card"_s;
        QVERIFY(Database::replaceAccounts(u"item-a"_s, {bank, card}));

        // No type (null QString): every account. A null bind value made the
        // "no filter" test false and the raw data page came out empty.
        AccountsModel all;
        all.reload();
        QCOMPARE(all.count(), 2);
        QCOMPARE(all.get(all.get(0).value(u"accountId"_s) == u"bank-1"_s ? 0 : 1).value(u"raw"_s).toString(), u"{\"id\":\"bank-1\"}"_s);

        AccountsModel cards;
        cards.setType(u"CREDIT"_s);
        cards.reload();
        QCOMPARE(cards.count(), 1);
        QCOMPARE(cards.get(0).value(u"accountId"_s).toString(), u"card-1"_s);
    }

    void removeItems()
    {
        QVERIFY(Database::removeItemsNotIn({}));
        QVERIFY(Database::isEmpty());
    }
};

QTEST_GUILESS_MAIN(CoreTest)
#include "coretest.moc"
