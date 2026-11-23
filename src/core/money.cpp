// SPDX-License-Identifier: MIT
#include "money.h"

#include <KLocalizedString>

#include <QLocale>
#include <QRegularExpression>

#include <cmath>

using namespace Qt::StringLiterals;

namespace
{
// Numbers (money in any currency, percentages, numeric dates) are always
// Brazilian, whatever the app's or the system's language: the app only works
// with Brazilian banks. Names follow the app's language (uiLocale()).
QLocale brazil()
{
    return QLocale(QLocale::Portuguese, QLocale::Brazil);
}

QString symbolFor(const QString &currency)
{
    if (currency.isEmpty() || currency == "BRL"_L1) {
        return u"R$"_s;
    }
    if (currency == "USD"_L1) {
        return u"US$"_s;
    }
    if (currency == "EUR"_L1) {
        return u"€"_s;
    }
    return currency;
}
}

QString MoneyFormat::format(double value, const QString &currency)
{
    if (std::abs(value) < 0.005) {
        return brazil().toCurrencyString(0.0, symbolFor(currency)); // never "-R$ 0,00"
    }
    // "-R$ 1,00" rather than the locale's "R$ -1,00"
    const QString text = brazil().toCurrencyString(std::abs(value), symbolFor(currency));
    return value < 0 ? u"-"_s + text : text;
}

QString MoneyFormat::formatSigned(double value, const QString &currency)
{
    const QString text = format(value, currency);
    return value >= 0.005 ? u"+"_s + text : text;
}

QString MoneyFormat::compact(double value, const QString &currency)
{
    const double magnitude = std::abs(value);
    const QLocale locale = brazil();
    const QString symbol = symbolFor(currency);
    const QString sign = value < 0 ? u"-"_s : QString();
    if (magnitude >= 1e6) {
        return sign + i18nc("compact money amount in millions, %1 currency symbol, %2 number", "%1 %2M", symbol, locale.toString(magnitude / 1e6, 'f', 1));
    }
    if (magnitude >= 1e4) {
        return sign + i18nc("compact money amount in thousands, %1 currency symbol, %2 number", "%1 %2K", symbol, locale.toString(magnitude / 1e3, 'f', 1));
    }
    const QString text = locale.toCurrencyString(std::round(magnitude), symbol, 0);
    return sign + text;
}

QString MoneyFormat::axisLabel(double value, double step, const QString &currency)
{
    const double magnitude = std::abs(value);
    const QLocale locale = brazil();
    const QString symbol = symbolFor(currency);
    const QString sign = value < -0.005 ? u"-"_s : QString();
    // One decimal only when the step needs it (2.5K steps).
    auto decimals = [](double unitStep) {
        return std::abs(unitStep - std::round(unitStep)) < 1e-6 ? 0 : 1;
    };
    step = std::abs(step);
    if (magnitude < 0.005) {
        return locale.toCurrencyString(0.0, symbol, 0);
    }
    if (step >= 1e6) {
        return sign + i18nc("compact money amount in millions, %1 currency symbol, %2 number", "%1 %2M", symbol, locale.toString(magnitude / 1e6, 'f', decimals(step / 1e6)));
    }
    if (step >= 1e3) {
        return sign + i18nc("compact money amount in thousands, %1 currency symbol, %2 number", "%1 %2K", symbol, locale.toString(magnitude / 1e3, 'f', decimals(step / 1e3)));
    }
    return sign + locale.toCurrencyString(std::round(magnitude), symbol, 0);
}

QString MoneyFormat::percent(double ratio)
{
    if (!std::isfinite(ratio)) {
        ratio = 0;
    }
    return i18nc("percentage", "%1%", brazil().toString(std::lround(ratio * 100)));
}

QString MoneyFormat::number(double value, int decimals)
{
    return brazil().toString(value, 'f', decimals);
}

QString MoneyFormat::relativeTime(const QDateTime &when)
{
    if (!when.isValid()) {
        return i18nc("time of an event that never happened", "never");
    }
    const qint64 secs = when.secsTo(QDateTime::currentDateTimeUtc());
    if (secs < 0) {
        const qint64 ahead = -secs;
        if (ahead < 3600) {
            return i18ncp("relative time in the future", "in %1 minute", "in %1 minutes", qMax<qint64>(1, ahead / 60));
        }
        if (ahead < 86400) {
            return i18ncp("relative time in the future", "in %1 hour", "in %1 hours", ahead / 3600);
        }
        return i18ncp("relative time in the future", "in %1 day", "in %1 days", ahead / 86400);
    }
    if (secs < 60) {
        return i18n("just now");
    }
    if (secs < 3600) {
        return i18np("%1 minute ago", "%1 minutes ago", secs / 60);
    }
    if (secs < 86400) {
        return i18np("%1 hour ago", "%1 hours ago", secs / 3600);
    }
    return i18np("%1 day ago", "%1 days ago", secs / 86400);
}

QLocale MoneyFormat::uiLocale()
{
    // KI18n's languages: the one picked in Settings, else the system's list.
    const QString language = KLocalizedString::languages().value(0);
    return language.isEmpty() ? QLocale::system() : QLocale(language);
}

QString MoneyFormat::shortDate(const QDate &date)
{
    if (!date.isValid()) {
        return QString();
    }
    return brazil().toString(date, QLocale::ShortFormat);
}

QString MoneyFormat::dayMonth(const QDate &date)
{
    if (!date.isValid()) {
        return QString();
    }
    // The short format minus the year and the separator next to it
    // ("dd/MM/yyyy" -> "dd/MM").
    static const QRegularExpression yearAtEnd(u"[^dM]*y+[^dM]*$"_s);
    static const QRegularExpression yearElsewhere(u"y+[^dM]*"_s);
    const QLocale locale = brazil();
    QString format = locale.dateFormat(QLocale::ShortFormat);
    format.remove(yearAtEnd);
    format.remove(yearElsewhere);
    return locale.toString(date, format.trimmed());
}

QString MoneyFormat::dayLabel(const QDate &date)
{
    const QDate today = QDate::currentDate();
    if (date == today) {
        return i18n("Today");
    }
    if (date == today.addDays(-1)) {
        return i18n("Yesterday");
    }
    QString label = uiLocale().toString(date, QLocale::LongFormat);
    if (!label.isEmpty()) {
        label[0] = label[0].toUpper();
    }
    return label;
}

QString MoneyFormat::monthLabel(const QDate &month)
{
    QString label = uiLocale().standaloneMonthName(month.month(), QLocale::LongFormat);
    if (!label.isEmpty()) {
        label[0] = label[0].toUpper();
    }
    return i18nc("%1 month name, %2 year", "%1 %2", label, QString::number(month.year()));
}

QString MoneyFormat::shortMonthLabel(const QDate &month)
{
    QString label = uiLocale().standaloneMonthName(month.month(), QLocale::ShortFormat);
    label.remove(u'.');
    return label;
}

Money::Money(QObject *parent)
    : QObject(parent)
{
}

QString Money::masked() const
{
    return u"R$ •••••"_s;
}

QString Money::format(double value, const QString &currency) const
{
    return MoneyFormat::format(value, currency);
}

QString Money::formatSigned(double value, const QString &currency) const
{
    return MoneyFormat::formatSigned(value, currency);
}

QString Money::compact(double value, const QString &currency) const
{
    return MoneyFormat::compact(value, currency);
}

QString Money::axisLabel(double value, double step, const QString &currency) const
{
    return MoneyFormat::axisLabel(value, step, currency);
}

QString Money::percent(double ratio) const
{
    return MoneyFormat::percent(ratio);
}

QString Money::number(double value, int decimals) const
{
    return MoneyFormat::number(value, decimals);
}

QString Money::relativeTime(const QDateTime &when) const
{
    return MoneyFormat::relativeTime(when);
}

QString Money::shortDate(const QDate &date) const
{
    return MoneyFormat::shortDate(date);
}

QString Money::dayMonth(const QDate &date) const
{
    return MoneyFormat::dayMonth(date);
}
