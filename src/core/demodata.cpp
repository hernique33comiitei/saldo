// SPDX-License-Identifier: MIT
#include "demodata.h"

#include "database.h"
#include "pluggyparser.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QSqlQuery>

#include <cmath>

using namespace Qt::StringLiterals;

namespace
{
// The account as Pluggy would send it (same keys PluggyParser reads), so the
// raw data page has something to show in the demo too.
AccountRecord withRaw(AccountRecord a)
{
    QJsonObject json{
        {u"id"_s, a.id},
        {u"itemId"_s, a.itemId},
        {u"type"_s, a.type},
        {u"subtype"_s, a.subtype},
        {u"name"_s, a.name},
        {u"number"_s, a.number},
        {u"balance"_s, a.balance},
        {u"currencyCode"_s, a.currency},
    };
    if (a.hasCredit) {
        json.insert(u"creditData"_s,
                    QJsonObject{
                        {u"level"_s, a.level},
                        {u"brand"_s, a.brand},
                        {u"balanceCloseDate"_s, a.closeDate.toString(Qt::ISODate)},
                        {u"balanceDueDate"_s, a.dueDate.toString(Qt::ISODate)},
                        {u"availableCreditLimit"_s, a.availableCreditLimit},
                        {u"creditLimit"_s, a.creditLimit},
                        {u"minimumPayment"_s, a.minimumPayment},
                        {u"holderType"_s, a.holderType},
                        {u"status"_s, u"ACTIVE"_s},
                    });
    }
    a.raw = QJsonDocument(json).toJson(QJsonDocument::Compact);
    return a;
}

struct Spend {
    QString description;
    QString category;
    double min;
    double max;
    int perMonth;
};

double money(QRandomGenerator &random, double min, double max)
{
    return std::round((min + random.generateDouble() * (max - min)) * 100.0) / 100.0;
}

TransactionRecord tx(const QString &id, const QString &accountType, const QDate &date, const QString &description, const QString &category, double amount)
{
    TransactionRecord t;
    t.id = id;
    t.date = date;
    t.description = description;
    t.category = category;
    t.amount = amount;
    t.normalizedAmount = PluggyParser::normalizedAmount(accountType, amount);
    t.currency = u"BRL"_s;
    t.status = date > QDate::currentDate().addDays(-2) ? u"PENDING"_s : u"POSTED"_s;
    t.type = amount < 0 ? u"DEBIT"_s : u"CREDIT"_s;
    return t;
}
}

QStringList DemoData::itemIds()
{
    return {u"0f9c2f5e-3c1a-4d1e-9a51-6f7d1b8e4a01"_s, u"0f9c2f5e-3c1a-4d1e-9a51-6f7d1b8e4a02"_s};
}

bool DemoData::populate()
{
    QRandomGenerator random(20261121);
    const QDate today = QDate::currentDate();
    const QDateTime now = QDateTime::currentDateTimeUtc();
    const QString bankItem = itemIds().at(0);
    const QString cardItem = itemIds().at(1);

    Database::clearAll();

    // Connections
    for (const auto &[id, name] : {std::pair{bankItem, u"Banco Exemplo"_s}, std::pair{cardItem, u"Cartões Exemplo"_s}}) {
        ItemRecord item;
        item.id = id;
        item.connectorName = name;
        item.status = u"UPDATED"_s;
        item.executionStatus = u"SUCCESS"_s;
        item.lastUpdatedAt = now.addSecs(-3 * 3600);
        item.nextAutoSyncAt = now.addSecs(21 * 3600);
        item.consentExpiresAt = now.addDays(290);
        Database::upsertItem(item);
    }

    // Accounts
    AccountRecord checking;
    checking.id = u"demo-checking"_s;
    checking.itemId = bankItem;
    checking.type = u"BANK"_s;
    checking.subtype = u"CHECKING_ACCOUNT"_s;
    checking.name = u"Conta Corrente"_s;
    checking.number = u"0001/12345-6"_s;
    checking.currency = u"BRL"_s;
    checking.balance = 8420.55;

    AccountRecord savings = checking;
    savings.id = u"demo-savings"_s;
    savings.subtype = u"SAVINGS_ACCOUNT"_s;
    savings.name = u"Poupança"_s;
    savings.number = u"0001/12345-7"_s;
    savings.balance = 15230.10;

    AccountRecord platinum;
    platinum.id = u"demo-card-platinum"_s;
    platinum.itemId = cardItem;
    platinum.type = u"CREDIT"_s;
    platinum.subtype = u"CREDIT_CARD"_s;
    platinum.name = u"Mastercard Platinum"_s;
    platinum.number = u"4821"_s;
    platinum.currency = u"BRL"_s;
    platinum.hasCredit = true;
    platinum.brand = u"MASTERCARD"_s;
    platinum.level = u"PLATINUM"_s;
    platinum.holderType = u"MAIN"_s;
    platinum.creditLimit = 12000;
    platinum.availableCreditLimit = 7349.62;
    platinum.balance = 3210.40;
    platinum.minimumPayment = 481.56;
    // Like Pluggy, creditData dates are those of the LAST CLOSED bill.
    platinum.closeDate = QDate(today.year(), today.month(), 3);
    if (platinum.closeDate >= today) {
        platinum.closeDate = platinum.closeDate.addMonths(-1);
    }
    platinum.dueDate = platinum.closeDate.addDays(7);

    AccountRecord gold = platinum;
    gold.id = u"demo-card-gold"_s;
    gold.name = u"Visa Gold"_s;
    gold.number = u"1937"_s;
    gold.brand = u"VISA"_s;
    gold.level = u"GOLD"_s;
    gold.creditLimit = 5000;
    gold.availableCreditLimit = 4102.30;
    gold.balance = 897.70;
    gold.minimumPayment = 134.65;
    gold.closeDate = QDate(today.year(), today.month(), 13);
    if (gold.closeDate >= today) {
        gold.closeDate = gold.closeDate.addMonths(-1);
    }
    gold.dueDate = gold.closeDate.addDays(7);

    Database::replaceAccounts(bankItem, {withRaw(checking), withRaw(savings)});
    Database::replaceAccounts(cardItem, {withRaw(platinum), withRaw(gold)});

    // Transactions: six months of salary, bills and everyday spending.
    const QDate from = QDate(today.year(), today.month(), 1).addMonths(-5);
    QList<TransactionRecord> checkingTx;
    QList<TransactionRecord> savingsTx{tx(u"demo-tx-0"_s, u"BANK"_s, from.addDays(20), u"Rendimento"_s, u"Interest"_s, 98.40)};
    QList<TransactionRecord> platinumTx;
    QList<TransactionRecord> goldTx;
    int n = 0;
    auto nextId = [&n]() {
        return u"demo-tx-%1"_s.arg(++n);
    };

    const QList<Spend> cardSpend = {
        {u"Supermercado Bom Preço"_s, u"Groceries"_s, 80, 420, 5},
        {u"Restaurante Sabor da Casa"_s, u"Food and drinks"_s, 35, 160, 6},
        {u"App de Delivery"_s, u"Food and drinks"_s, 28, 95, 5},
        {u"Posto Avenida"_s, u"Gas stations"_s, 120, 260, 2},
        {u"Corrida App"_s, u"Taxi and ride-hailing"_s, 14, 48, 6},
        {u"Loja Online"_s, u"Online shopping"_s, 60, 540, 2},
        {u"Farmácia Central"_s, u"Pharmacy"_s, 25, 140, 2},
        {u"Cinema Shopping"_s, u"Entertainment"_s, 40, 120, 1},
    };
    const QList<Spend> goldSpend = {
        {u"Streaming de Vídeo"_s, u"Video streaming"_s, 39.90, 39.90, 1},
        {u"Streaming de Música"_s, u"Music streaming"_s, 21.90, 21.90, 1},
        {u"Academia Movimento"_s, u"Gyms and fitness centers"_s, 119.90, 119.90, 1},
        {u"Livraria Página"_s, u"Bookstore"_s, 45, 180, 1},
    };

    for (QDate month = from; month <= today; month = month.addMonths(1)) {
        const int days = month.daysInMonth();
        auto day = [&](int d) {
            return QDate(month.year(), month.month(), qMin(d, days));
        };
        auto addIfPast = [&](QList<TransactionRecord> &list, const TransactionRecord &t) {
            if (t.date <= today) {
                list.append(t);
            }
        };

        addIfPast(checkingTx, tx(nextId(), u"BANK"_s, day(5), u"Salário Empresa Exemplo"_s, u"Salary"_s, 9850.00));
        addIfPast(checkingTx, tx(nextId(), u"BANK"_s, day(8), u"Aluguel"_s, u"Rent"_s, -2650.00));
        addIfPast(checkingTx, tx(nextId(), u"BANK"_s, day(10), u"Energia Elétrica"_s, u"Electricity"_s, -money(random, 160, 290)));
        addIfPast(checkingTx, tx(nextId(), u"BANK"_s, day(12), u"Internet Fibra"_s, u"Internet"_s, -119.90));
        addIfPast(checkingTx, tx(nextId(), u"BANK"_s, day(15), u"Pix recebido"_s, u"Transfer - PIX"_s, money(random, 50, 400)));
        addIfPast(checkingTx, tx(nextId(), u"BANK"_s, day(16), u"Aplicação CDB"_s, u"Fixed income"_s, -1000.00));
        // PIX from checking to savings: a transfer between own accounts.
        const QDate savingDay = day(20);
        if (savingDay <= today) {
            checkingTx.append(tx(nextId(), u"BANK"_s, savingDay, u"Pix enviado - Poupança"_s, u"Transfer - PIX"_s, -500.00));
            savingsTx.append(tx(nextId(), u"BANK"_s, savingDay, u"Pix recebido - Conta Corrente"_s, u"Transfer - PIX"_s, 500.00));
        }

        for (const Spend &spend : cardSpend) {
            for (int i = 0; i < spend.perMonth; ++i) {
                addIfPast(platinumTx,
                          tx(nextId(), u"CREDIT"_s, day(1 + random.bounded(days)), spend.description, spend.category, money(random, spend.min, spend.max)));
            }
        }
        for (const Spend &spend : goldSpend) {
            addIfPast(goldTx, tx(nextId(), u"CREDIT"_s, day(3 + random.bounded(20)), spend.description, spend.category, money(random, spend.min, spend.max)));
        }
    }

    // An installment purchase.
    for (int i = 0; i < 6; ++i) {
        TransactionRecord t = tx(nextId(), u"CREDIT"_s, from.addMonths(i).addDays(17), u"Notebook Loja Tech"_s, u"Electronics"_s, 549.90);
        t.installmentNumber = i + 1;
        t.totalInstallments = 10;
        if (t.date <= today) {
            platinumTx.append(t);
        }
    }

    // Purchases up to the last closing belong to a closed bill (billId);
    // newer ones form the open bill. Payments never carry a billId.
    auto assignBills = [](QList<TransactionRecord> &transactions, const AccountRecord &card) {
        QHash<QString, BillRecord> bills;
        for (TransactionRecord &t : transactions) {
            if (t.normalizedAmount >= 0 || t.date > card.closeDate) {
                continue;
            }
            int cycle = 0;
            while (t.date <= card.closeDate.addMonths(-(cycle + 1))) {
                ++cycle;
            }
            t.billId = u"%1-bill-%2"_s.arg(card.id).arg(cycle);
            BillRecord &bill = bills[t.billId];
            bill.id = t.billId;
            bill.accountId = card.id;
            bill.closingDate = card.closeDate.addMonths(-cycle);
            bill.dueDate = card.dueDate.addMonths(-cycle);
            bill.totalAmount += -t.normalizedAmount;
            bill.currency = u"BRL"_s;
        }
        QList<BillRecord> list = bills.values();
        for (BillRecord &bill : list) {
            bill.totalAmount = std::round(bill.totalAmount * 100) / 100.0;
            bill.minimumPayment = std::round(bill.totalAmount * 15) / 100.0;
        }
        return list;
    };
    const QList<BillRecord> platinumBills = assignBills(platinumTx, platinum);
    assignBills(goldTx, gold); // this one has no bill history, only billIds

    // Each closed bill paid in full from checking the day before it is due.
    // Like real Pluggy data, the bank side is a generic "Transfers" and the
    // card side "Shopping": only the matching amount tells it is a payment.
    for (const BillRecord &bill : platinumBills) {
        const QDate paymentDay = bill.dueDate.addDays(-1);
        if (paymentDay <= today) {
            checkingTx.append(tx(nextId(), u"BANK"_s, paymentDay, u"Pagamento fatura cartão"_s, u"Transfers"_s, -bill.totalAmount));
            platinumTx.append(tx(nextId(), u"CREDIT"_s, std::min(bill.dueDate, today), u"Pagamento recebido"_s, u"Shopping"_s, -bill.totalAmount));
        }
    }

    Database::replaceTransactions(checking.id, QDate(), checkingTx);
    Database::replaceTransactions(savings.id, QDate(), savingsTx);
    Database::replaceTransactions(platinum.id, QDate(), platinumTx);
    Database::replaceTransactions(gold.id, QDate(), goldTx);
    Database::replaceBills(platinum.id, platinumBills);

    // Investments
    QList<InvestmentRecord> investments;
    auto investment = [&](const QString &id, const QString &name, const QString &type, const QString &subtype, double balance, double profit, double rate) {
        InvestmentRecord r;
        r.id = id;
        r.itemId = bankItem;
        r.name = name;
        r.type = type;
        r.subtype = subtype;
        r.currency = u"BRL"_s;
        r.status = u"ACTIVE"_s;
        r.institution = u"Banco Exemplo"_s;
        r.balance = balance;
        r.amount = balance * 1.04;
        r.amountProfit = profit;
        r.lastTwelveMonthsRate = rate;
        r.dueDate = today.addMonths(18);
        investments.append(r);
    };
    investment(u"demo-inv-1"_s, u"CDB Banco Exemplo 110% CDI"_s, u"FIXED_INCOME"_s, u"CDB"_s, 20450.32, 1450.32, 12.1);
    investment(u"demo-inv-2"_s, u"Tesouro IPCA+ 2035"_s, u"FIXED_INCOME"_s, u"TREASURY"_s, 12510.87, 810.87, 9.4);
    investment(u"demo-inv-3"_s, u"Fundo Imobiliário XPTO11"_s, u"MUTUAL_FUND"_s, u"REAL_ESTATE_FUND"_s, 6230.00, -120.00, 6.8);
    investment(u"demo-inv-4"_s, u"ETF Ibovespa"_s, u"ETF"_s, u"ETF"_s, 4120.45, 320.45, 14.2);
    Database::replaceInvestments(bankItem, investments);

    // Categories (Portuguese translations as Pluggy returns them).
    QList<CategoryRecord> categories;
    const QList<std::pair<QString, QString>> names = {
        {u"Groceries"_s, u"Supermercado"_s},
        {u"Food and drinks"_s, u"Alimentação"_s},
        {u"Gas stations"_s, u"Postos de gasolina"_s},
        {u"Taxi and ride-hailing"_s, u"Táxi e transporte por app"_s},
        {u"Online shopping"_s, u"Compras online"_s},
        {u"Pharmacy"_s, u"Farmácia"_s},
        {u"Entertainment"_s, u"Entretenimento"_s},
        {u"Video streaming"_s, u"Streaming de vídeo"_s},
        {u"Music streaming"_s, u"Streaming de música"_s},
        {u"Gyms and fitness centers"_s, u"Academias"_s},
        {u"Bookstore"_s, u"Livrarias"_s},
        {u"Salary"_s, u"Salário"_s},
        {u"Rent"_s, u"Aluguel"_s},
        {u"Electricity"_s, u"Energia elétrica"_s},
        {u"Internet"_s, u"Internet"_s},
        {u"Electronics"_s, u"Eletrônicos"_s},
        {u"Fixed income"_s, u"Renda fixa"_s},
        {u"Transfer - PIX"_s, u"Transferência - PIX"_s},
        {u"Credit card payment"_s, u"Pagamento de cartão"_s},
        {u"Interest"_s, u"Juros"_s},
    };
    int categoryId = 0;
    for (const auto &[en, pt] : names) {
        CategoryRecord c;
        c.id = u"%1"_s.arg(++categoryId * 1000000, 8, 10, QLatin1Char('0'));
        c.description = en;
        c.descriptionTranslated = pt;
        categories.append(c);
    }
    Database::replaceCategories(categories);

    Database::detectInternalTransfers();

    // 90 days of balance history (demo transactions are consistent, so the
    // balances can be walked back from today).
    for (const auto &[account, transactions] : {std::pair{&checking, &checkingTx}, std::pair{&savings, &savingsTx}}) {
        QHash<QDate, double> perDay;
        for (const TransactionRecord &t : *transactions) {
            perDay[t.date] += t.normalizedAmount;
        }
        double balance = account->balance;
        QSqlQuery insert(Database::connection());
        insert.prepare(u"INSERT OR REPLACE INTO balance_snapshots (day, account_id, balance) VALUES (?, ?, ?)"_s);
        for (QDate day = today; day > today.addDays(-90); day = day.addDays(-1)) {
            insert.addBindValue(day.toString(Qt::ISODate));
            insert.addBindValue(account->id);
            insert.addBindValue(balance);
            insert.exec();
            balance -= perDay.value(day, 0.0);
        }
    }

    Database::setMeta(u"lastSyncAt"_s, now.toString(Qt::ISODateWithMs));
    return true;
}
