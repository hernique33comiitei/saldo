// SPDX-License-Identifier: MIT
#include "financesummary.h"

#include "cardbills.h"
#include "categories.h"
#include "config.h"
#include "database.h"
#include "money.h"
#include "paths.h"

#include <KLocalizedString>

#include <QCoreApplication>
#include <QSqlQuery>
#include <QTimer>

using namespace Qt::StringLiterals;

FinanceSummary *FinanceSummary::instance()
{
    static FinanceSummary *summary = new FinanceSummary(QCoreApplication::instance());
    return summary;
}

FinanceSummary *FinanceSummary::create(QQmlEngine *, QJSEngine *)
{
    FinanceSummary *summary = instance();
    QJSEngine::setObjectOwnership(summary, QJSEngine::CppOwnership);
    return summary;
}

FinanceSummary::FinanceSummary(QObject *parent)
    : QObject(parent)
{
    connect(Database::instance(), &Database::dataChanged, this, &FinanceSummary::scheduleReload);
    connect(Config::instance(), &Config::excludedCardIdsChanged, this, &FinanceSummary::scheduleReload);
    connect(Config::instance(), &Config::itemNamesChanged, this, &FinanceSummary::scheduleReload);
    // Day changes (month totals, consent countdown).
    auto *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &FinanceSummary::reload);
    timer->start(30 * 60 * 1000);
    reload();
}

void FinanceSummary::scheduleReload()
{
    if (m_reloadPending) {
        return;
    }
    m_reloadPending = true;
    QTimer::singleShot(0, this, &FinanceSummary::reload);
}

void FinanceSummary::reload()
{
    m_reloadPending = false;
    QSqlDatabase db = Database::connection();
    QSqlQuery q(db);

    q.exec(u"SELECT COALESCE(SUM(balance), 0), COUNT(*) FROM accounts WHERE type = 'BANK'"_s);
    m_totalCash = q.next() ? q.value(0).toDouble() : 0;
    m_accountCount = q.value(1).toInt();

    q.exec(u"SELECT COALESCE(SUM(balance), 0), COUNT(*) FROM investments WHERE COALESCE(status, '') <> 'TOTAL_WITHDRAWAL'"_s);
    m_totalInvested = q.next() ? q.value(0).toDouble() : 0;
    m_investmentCount = q.value(1).toInt();

    QList<CardLimitRow> cards;
    QList<std::pair<QDate, QDate>> creditDates;
    q.exec(u"SELECT id, item_id, holder_type, credit_limit, available_credit_limit, close_date, due_date FROM accounts WHERE type = 'CREDIT' ORDER BY item_id, name"_s);
    while (q.next()) {
        cards.append({q.value(0).toString(), q.value(1).toString(), q.value(2).toString(), q.value(3).toDouble(), q.value(4).toDouble()});
        creditDates.append({QDate::fromString(q.value(5).toString(), Qt::ISODate), QDate::fromString(q.value(6).toString(), Qt::ISODate)});
    }
    m_cardCount = cards.size();
    const QStringList excluded = Config::instance()->excludedCardIds();
    m_cards = computeCardTotals(cards, excluded);

    m_nextBills = 0;
    m_nextBillDue = {};
    for (qsizetype i = 0; i < cards.size(); ++i) {
        if (excluded.contains(cards.at(i).id)) {
            continue;
        }
        const CardBill bill = computeCardBill(cards.at(i).id, creditDates.at(i).first, creditDates.at(i).second);
        if (bill.toPay() > 0.005) {
            m_nextBills += bill.toPay();
            const QDate due = bill.nextDue();
            if (due.isValid() && (!m_nextBillDue.isValid() || due < m_nextBillDue)) {
                m_nextBillDue = due;
            }
        }
    }

    const QString month = QDate::currentDate().toString(u"yyyy-MM"_s);
    q.prepare(u"SELECT "_s + Database::incomeSql() + u", "_s + Database::expenseSql()
              + u" FROM transactions t JOIN accounts a ON a.id = t.account_id WHERE substr(t.date, 1, 7) = ? AND "_s
              + Database::countedSql());
    q.addBindValue(month);
    q.exec();
    if (q.next()) {
        m_monthIncome = q.value(0).toDouble();
        m_monthExpenses = q.value(1).toDouble();
    }

    // Connections: freshness and problems that need the user.
    m_attention.clear();
    m_connectionCount = 0;
    m_dataUpdatedAt = {};
    m_nextAutoSyncAt = {};
    q.exec(u"SELECT id, connector_name, status, error_code, error_message, last_updated_at, consent_expires_at, next_auto_sync_at FROM items"_s);
    const QDateTime now = QDateTime::currentDateTimeUtc();
    while (q.next()) {
        const QString itemId = q.value(0).toString();
        if (!Paths::isDemo() && !Config::instance()->itemIds().contains(itemId)) {
            continue;
        }
        ++m_connectionCount;
        const QString name = Config::instance()->displayItemName(itemId, q.value(1).toString());
        const QString status = q.value(2).toString();
        const QDateTime updated = QDateTime::fromString(q.value(5).toString(), Qt::ISODateWithMs);
        const QDateTime consent = QDateTime::fromString(q.value(6).toString(), Qt::ISODateWithMs);
        const QDateTime next = QDateTime::fromString(q.value(7).toString(), Qt::ISODateWithMs);
        if (updated.isValid() && (!m_dataUpdatedAt.isValid() || updated < m_dataUpdatedAt)) {
            m_dataUpdatedAt = updated;
        }
        if (next.isValid() && (!m_nextAutoSyncAt.isValid() || next < m_nextAutoSyncAt)) {
            m_nextAutoSyncAt = next;
        }
        if (status == "LOGIN_ERROR"_L1 || status == "OUTDATED"_L1 || q.value(3).toString() == "USER_AUTHORIZATION_EXPIRED"_L1) {
            m_attention.append(i18n("%1 needs to be reconnected in the Pluggy dashboard (status %2).", name, status));
        } else if (consent.isValid()) {
            const qint64 days = now.daysTo(consent);
            if (days <= 30) {
                m_attention.append(i18np("The Meu Pluggy authorization for %2 expires in %1 day. Renew it in the Pluggy dashboard.",
                                         "The Meu Pluggy authorization for %2 expires in %1 days. Renew it in the Pluggy dashboard.",
                                         qMax<qint64>(0, days),
                                         name));
            }
        }
        if (updated.isValid() && updated.secsTo(now) > 48 * 3600) {
            m_attention.append(i18n("%1 has not been updated by Pluggy for %2.", name, MoneyFormat::relativeTime(updated)));
        }
    }

    m_months.clear();
    q.exec(u"SELECT DISTINCT substr(date, 1, 7) AS month FROM transactions WHERE date IS NOT NULL ORDER BY month DESC"_s);
    while (q.next()) {
        const QString value = q.value(0).toString();
        const QDate first = QDate::fromString(value + u"-01"_s, Qt::ISODate);
        if (first.isValid()) {
            m_months.append(QVariantMap{{u"value"_s, value}, {u"text"_s, MoneyFormat::monthLabel(first)}});
        }
    }

    Q_EMIT changed();
}

bool FinanceSummary::hasData() const
{
    return m_accountCount + m_cardCount + m_investmentCount > 0;
}

double FinanceSummary::totalCash() const
{
    return m_totalCash;
}

double FinanceSummary::totalInvested() const
{
    return m_totalInvested;
}

double FinanceSummary::cardLimit() const
{
    return m_cards.limit;
}

double FinanceSummary::cardUsed() const
{
    return m_cards.used;
}

double FinanceSummary::cardAvailable() const
{
    return m_cards.available;
}

double FinanceSummary::cardUsedRatio() const
{
    return m_cards.usedRatio();
}

double FinanceSummary::nextBills() const
{
    return m_nextBills;
}

QDate FinanceSummary::nextBillDue() const
{
    return m_nextBillDue;
}

double FinanceSummary::monthIncome() const
{
    return m_monthIncome;
}

double FinanceSummary::monthExpenses() const
{
    return m_monthExpenses;
}

int FinanceSummary::connectionCount() const
{
    return m_connectionCount;
}

int FinanceSummary::accountCount() const
{
    return m_accountCount;
}

int FinanceSummary::cardCount() const
{
    return m_cardCount;
}

int FinanceSummary::investmentCount() const
{
    return m_investmentCount;
}

QDateTime FinanceSummary::dataUpdatedAt() const
{
    return m_dataUpdatedAt;
}

QDateTime FinanceSummary::nextAutoSyncAt() const
{
    return m_nextAutoSyncAt;
}

QStringList FinanceSummary::attention() const
{
    return m_attention;
}

QVariantList FinanceSummary::months() const
{
    return m_months;
}
