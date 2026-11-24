// SPDX-License-Identifier: MIT
#include "config.h"

#include "credentials.h"
#include "demodata.h"
#include "paths.h"

#include <KLocalizedString>

#include <QCoreApplication>
#include <QFileInfo>
#include <QRegularExpression>

using namespace Qt::StringLiterals;

namespace
{
const auto KeyItemIds = u"Pluggy/itemIds"_s;
const auto KeyHistoryMonths = u"Sync/historyMonths"_s;
const auto KeyRefreshMinutes = u"Sync/refreshMinutes"_s;
const auto KeyPrivacyMode = u"View/privacyMode"_s;
const auto KeyExcludedCards = u"View/excludedCardIds"_s;
const auto KeyCredentialsRevision = u"Pluggy/credentialsRevision"_s;
const auto KeySetupStep = u"Setup/step"_s;
const auto KeyLanguage = u"View/language"_s;
const QStringList Languages = {QString(), u"en"_s, u"pt_BR"_s};
const auto KeyTheme = u"View/theme"_s;
const QStringList Themes = {QString(), u"light"_s, u"dark"_s};
const auto GroupItemNames = u"ItemNames"_s;

const QRegularExpression &uuidPattern()
{
    static const QRegularExpression uuid(u"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"_s);
    return uuid;
}
}

Config *Config::instance()
{
    static Config *config = new Config(QCoreApplication::instance());
    return config;
}

Config *Config::create(QQmlEngine *, QJSEngine *)
{
    Config *config = instance();
    QJSEngine::setObjectOwnership(config, QJSEngine::CppOwnership);
    return config;
}

Config::Config(QObject *parent)
    : QObject(parent)
    , m_settings(Paths::configFile(), QSettings::IniFormat)
{
    load();
    watch();
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &Config::onFileChanged);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Config::onFileChanged);
}

void Config::load()
{
    m_itemIds = m_settings.value(KeyItemIds).toStringList();
    if (m_itemIds.isEmpty() && Paths::isDemo()) {
        m_itemIds = DemoData::itemIds();
    }
    m_historyMonths = qBound(1, m_settings.value(KeyHistoryMonths, 12).toInt(), 24);
    m_refreshMinutes = qBound(15, m_settings.value(KeyRefreshMinutes, 60).toInt(), 24 * 60);
    m_privacyMode = m_settings.value(KeyPrivacyMode, false).toBool();
    m_excludedCardIds = m_settings.value(KeyExcludedCards).toStringList();
    m_credentialsRevision = m_settings.value(KeyCredentialsRevision, 0).toInt();
    m_setupStep = m_settings.value(KeySetupStep, 0).toInt();
    m_language = m_settings.value(KeyLanguage).toString();
    if (!Languages.contains(m_language)) {
        m_language.clear();
    }
    m_theme = m_settings.value(KeyTheme).toString();
    if (!Themes.contains(m_theme)) {
        m_theme.clear();
    }

    m_itemNames.clear();
    m_settings.beginGroup(GroupItemNames);
    const QStringList keys = m_settings.childKeys();
    for (const QString &key : keys) {
        m_itemNames.insert(key, m_settings.value(key).toString());
    }
    m_settings.endGroup();
}

void Config::write(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
    m_settings.sync(); // QSettings writes through a temporary file + rename
    watch();
}

void Config::watch()
{
    const QString file = m_settings.fileName();
    const QString dir = QFileInfo(file).absolutePath();
    if (!m_watcher.directories().contains(dir)) {
        m_watcher.addPath(dir);
    }
    if (QFileInfo::exists(file) && !m_watcher.files().contains(file)) {
        m_watcher.addPath(file);
    }
}

void Config::onFileChanged()
{
    watch();
    m_settings.sync();

    const QStringList oldItems = m_itemIds;
    const int oldHistory = m_historyMonths;
    const int oldRefresh = m_refreshMinutes;
    const bool oldPrivacy = m_privacyMode;
    const QStringList oldExcluded = m_excludedCardIds;
    const int oldRevision = m_credentialsRevision;
    const int oldSetupStep = m_setupStep;
    const QString oldLanguage = m_language;
    const QString oldTheme = m_theme;
    const QHash<QString, QString> oldNames = m_itemNames;

    load();

    if (oldItems != m_itemIds) {
        Q_EMIT itemIdsChanged();
    }
    if (oldHistory != m_historyMonths) {
        Q_EMIT historyMonthsChanged();
    }
    if (oldRefresh != m_refreshMinutes) {
        Q_EMIT refreshMinutesChanged();
    }
    if (oldPrivacy != m_privacyMode) {
        Q_EMIT privacyModeChanged();
    }
    if (oldExcluded != m_excludedCardIds) {
        Q_EMIT excludedCardIdsChanged();
    }
    if (oldLanguage != m_language) {
        Q_EMIT languageChanged();
    }
    if (oldTheme != m_theme) {
        Q_EMIT themeChanged();
    }
    if (oldRevision != m_credentialsRevision) {
        Q_EMIT credentialsRevisionChanged();
    }
    if (oldSetupStep != m_setupStep) {
        Q_EMIT setupStepChanged();
    }
    if (oldNames != m_itemNames) {
        Q_EMIT itemNamesChanged();
    }
}

QStringList Config::itemIds() const
{
    return m_itemIds;
}

void Config::setItemIds(const QStringList &ids)
{
    if (ids == m_itemIds) {
        return;
    }
    m_itemIds = ids;
    write(KeyItemIds, m_itemIds);
    Q_EMIT itemIdsChanged();
}

int Config::historyMonths() const
{
    return m_historyMonths;
}

void Config::setHistoryMonths(int months)
{
    months = qBound(1, months, 24);
    if (months == m_historyMonths) {
        return;
    }
    m_historyMonths = months;
    write(KeyHistoryMonths, months);
    Q_EMIT historyMonthsChanged();
}

int Config::refreshMinutes() const
{
    return m_refreshMinutes;
}

void Config::setRefreshMinutes(int minutes)
{
    minutes = qBound(15, minutes, 24 * 60);
    if (minutes == m_refreshMinutes) {
        return;
    }
    m_refreshMinutes = minutes;
    write(KeyRefreshMinutes, minutes);
    Q_EMIT refreshMinutesChanged();
}

bool Config::privacyMode() const
{
    return m_privacyMode;
}

void Config::setPrivacyMode(bool enabled)
{
    if (enabled == m_privacyMode) {
        return;
    }
    m_privacyMode = enabled;
    write(KeyPrivacyMode, enabled);
    Q_EMIT privacyModeChanged();
}

QString Config::language() const
{
    return m_language;
}

void Config::setLanguage(const QString &language)
{
    if (!Languages.contains(language) || language == m_language) {
        return;
    }
    m_language = language;
    write(KeyLanguage, language);
    Q_EMIT languageChanged();
}

QString Config::theme() const
{
    return m_theme;
}

void Config::setTheme(const QString &theme)
{
    if (!Themes.contains(theme) || theme == m_theme) {
        return;
    }
    m_theme = theme;
    write(KeyTheme, theme);
    Q_EMIT themeChanged();
}

QString Config::storedLanguage()
{
    const QString language = QSettings(Paths::configFile(), QSettings::IniFormat).value(KeyLanguage).toString();
    return Languages.contains(language) ? language : QString();
}

QStringList Config::excludedCardIds() const
{
    return m_excludedCardIds;
}

int Config::credentialsRevision() const
{
    return m_credentialsRevision;
}

int Config::setupStep() const
{
    return m_setupStep;
}

void Config::setSetupStep(int step)
{
    if (step == m_setupStep) {
        return;
    }
    m_setupStep = step;
    write(KeySetupStep, step);
    Q_EMIT setupStepChanged();
}

bool Config::isValidItemId(const QString &id)
{
    const QString clean = id.trimmed();
    const QRegularExpressionMatch match = uuidPattern().match(clean);
    return match.hasMatch() && match.capturedLength() == clean.size();
}

QStringList Config::findIds(const QString &text)
{
    QStringList ids;
    auto it = uuidPattern().globalMatch(text);
    while (it.hasNext()) {
        const QString id = it.next().captured().toLower();
        if (!ids.contains(id)) {
            ids.append(id);
        }
    }
    return ids;
}

QString Config::addItemId(const QString &id)
{
    const QString clean = id.trimmed().toLower();
    if (!isValidItemId(clean)) {
        return i18n("This does not look like an item ID. It is a UUID such as 3fa85f64-5717-4562-b3fc-2c963f66afa6.");
    }
    if (clean.compare(Credentials::instance()->clientId(), Qt::CaseInsensitive) == 0) {
        return i18nc("Itens Conectados is a label in the Pluggy dashboard; keep it as is",
                     "That is the Client ID. The item ID is on the demo page of the Pluggy dashboard, under \"Itens Conectados\".");
    }
    if (m_itemIds.contains(clean)) {
        return i18n("This connection is already in the list.");
    }
    if (m_itemIds.size() >= MaxItems) {
        return i18np("Meu Pluggy personal use allows at most %1 connection.", "Meu Pluggy personal use allows at most %1 connections.", MaxItems);
    }
    setItemIds(m_itemIds + QStringList{clean});
    return QString();
}

void Config::removeItemId(const QString &id)
{
    QStringList ids = m_itemIds;
    if (ids.removeAll(id) > 0) {
        setItemName(id, QString());
        setItemIds(ids);
    }
}

QString Config::itemName(const QString &itemId) const
{
    return m_itemNames.value(itemId);
}

void Config::setItemName(const QString &itemId, const QString &name)
{
    const QString clean = name.trimmed();
    if (clean == m_itemNames.value(itemId)) {
        return;
    }
    if (clean.isEmpty()) {
        m_itemNames.remove(itemId);
        m_settings.remove(GroupItemNames + u'/' + itemId);
        m_settings.sync();
        watch();
    } else {
        m_itemNames.insert(itemId, clean);
        write(GroupItemNames + u'/' + itemId, clean);
    }
    Q_EMIT itemNamesChanged();
}

QString Config::displayItemName(const QString &itemId, const QString &connectorName) const
{
    const QString name = m_itemNames.value(itemId);
    if (!name.isEmpty()) {
        return name;
    }
    QString compactConnector = connectorName.toLower();
    compactConnector.remove(u' ');
    if (!connectorName.isEmpty() && compactConnector != "meupluggy"_L1) {
        return connectorName;
    }
    return i18nc("connection the user has not named yet; %1 is the start of its id", "Meu Pluggy · %1", itemId.left(4));
}

bool Config::isCardIncluded(const QString &accountId) const
{
    return !m_excludedCardIds.contains(accountId);
}

void Config::setCardIncluded(const QString &accountId, bool included)
{
    if (included == isCardIncluded(accountId)) {
        return;
    }
    if (included) {
        m_excludedCardIds.removeAll(accountId);
    } else {
        m_excludedCardIds.append(accountId);
    }
    write(KeyExcludedCards, m_excludedCardIds);
    Q_EMIT excludedCardIdsChanged();
}

void Config::bumpCredentialsRevision()
{
    ++m_credentialsRevision;
    write(KeyCredentialsRevision, m_credentialsRevision);
    Q_EMIT credentialsRevisionChanged();
}
