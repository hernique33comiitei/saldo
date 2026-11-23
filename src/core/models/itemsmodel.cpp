// SPDX-License-Identifier: MIT
#include "itemsmodel.h"

#include "config.h"
#include "database.h"
#include "money.h"
#include "paths.h"

#include <KLocalizedString>

#include <QSqlQuery>

using namespace Qt::StringLiterals;

namespace
{
QString statusLabel(const QString &status)
{
    if (status.isEmpty()) {
        return i18n("Not synced yet");
    }
    if (status == "UPDATED"_L1) {
        return i18n("Up to date");
    }
    if (status == "UPDATING"_L1) {
        return i18n("Updating at Pluggy");
    }
    if (status == "LOGIN_ERROR"_L1) {
        return i18n("Authorization expired");
    }
    if (status == "OUTDATED"_L1) {
        return i18n("Outdated");
    }
    if (status == "WAITING_USER_INPUT"_L1) {
        return i18n("Waiting for user action");
    }
    return status;
}
}

ItemsModel::ItemsModel(QObject *parent)
    : RowListModel({"itemId", "connectorName", "nickname", "accountsSummary", "status", "statusLabel", "healthy", "errorMessage",
                    "lastUpdatedLabel", "nextSyncLabel", "consentLabel"},
                   parent)
{
    connect(Config::instance(), &Config::itemIdsChanged, this, &ItemsModel::scheduleReload);
    connect(Config::instance(), &Config::itemNamesChanged, this, &ItemsModel::scheduleReload);
}

QList<QVariantMap> ItemsModel::fetchRows()
{
    QStringList ids = Config::instance()->itemIds();
    QSqlQuery q(Database::connection());
    if (Paths::isDemo()) {
        q.exec(u"SELECT id FROM items"_s);
        while (q.next()) {
            ids.append(q.value(0).toString());
        }
    }

    QList<QVariantMap> rows;
    for (const QString &id : std::as_const(ids)) {
        q.prepare(u"SELECT connector_name, status, error_message, last_updated_at, next_auto_sync_at, consent_expires_at FROM items WHERE id = ?"_s);
        q.addBindValue(id);
        q.exec();
        const bool known = q.next();
        const QString status = known ? q.value(1).toString() : QString();
        const QDateTime updated = QDateTime::fromString(q.value(3).toString(), Qt::ISODateWithMs);
        const QDateTime next = QDateTime::fromString(q.value(4).toString(), Qt::ISODateWithMs);
        const QDateTime consent = QDateTime::fromString(q.value(5).toString(), Qt::ISODateWithMs);
        const QString connector = known ? q.value(0).toString() : QString();
        const QString errorMessage = known ? q.value(2).toString() : QString();

        // The accounts help tell connections apart ("Conta · Ultravioleta").
        QSqlQuery accounts(Database::connection());
        accounts.prepare(u"SELECT COALESCE(NULLIF(marketing_name, ''), name) FROM accounts WHERE item_id = ? ORDER BY type, name LIMIT 4"_s);
        accounts.addBindValue(id);
        accounts.exec();
        QStringList names;
        while (accounts.next()) {
            names.append(accounts.value(0).toString());
        }

        rows.append(QVariantMap{
            {u"itemId"_s, id},
            {u"connectorName"_s, Config::instance()->displayItemName(id, connector)},
            {u"nickname"_s, Config::instance()->itemName(id)},
            {u"accountsSummary"_s, names.join(u" · "_s)},
            {u"status"_s, status},
            {u"statusLabel"_s, statusLabel(status)},
            {u"healthy"_s, status == "UPDATED"_L1 || status == "UPDATING"_L1},
            {u"errorMessage"_s, errorMessage},
            {u"lastUpdatedLabel"_s, updated.isValid() ? MoneyFormat::relativeTime(updated) : QString()},
            {u"nextSyncLabel"_s, next.isValid() ? MoneyFormat::relativeTime(next) : QString()},
            {u"consentLabel"_s, consent.isValid() ? MoneyFormat::shortDate(consent.toLocalTime().date()) : QString()},
        });
    }
    return rows;
}
