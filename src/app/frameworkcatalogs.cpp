// SPDX-License-Identifier: MIT
#include "frameworkcatalogs.h"

#include <QCoreApplication>
#include <QEvent>
#include <QFile>
#include <QLibraryInfo>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QTranslator>

using namespace Qt::StringLiterals;

namespace
{
// Catalogs whose texts show in the app. Loaded up front because a library
// finds no catalog for some system languages (Kirigami has no "en" one) and
// then installs nothing this could replace.
const QStringList KnownCatalogs = {u"libkirigami6_qt"_s, u"qqc2desktopstyle_qt"_s, u"kcoreaddons6_qt"_s};

// A KDE Frameworks catalog (".../locale/pt_BR/LC_MESSAGES/libkirigami6_qt.qm",
// found where ECMQmLoader looks) or one of Qt's (".../translations/qt_pt_BR.qm";
// "assets:/translations" in the APK).
struct Catalog {
    QString name;
    QString language;
    QString qtDir; // set for Qt's catalogs
};

Catalog catalogOf(const QString &path)
{
    static const QRegularExpression frameworks(u"/locale/([^/]+)/LC_MESSAGES/([^/]+)\\.qm$"_s);
    static const QRegularExpression qt(u"^(.*/translations)/(.+?)_([a-z]{2,3}(?:_[A-Z]{2})?)\\.qm$"_s);
    if (const auto match = frameworks.match(path); match.hasMatch()) {
        return {match.captured(2), match.captured(1), QString()};
    }
    if (const auto match = qt.match(path); match.hasMatch()) {
        return {match.captured(2), match.captured(3), match.captured(1)};
    }
    return {};
}

QString catalogFile(const Catalog &catalog)
{
    if (!catalog.qtDir.isEmpty()) {
        const QString path = catalog.qtDir + u'/' + catalog.name + u'_' + catalog.language + u".qm"_s;
        return QFile::exists(path) ? path : QString();
    }
    const QString subPath = u"locale/"_s + catalog.language + u"/LC_MESSAGES/"_s + catalog.name + u".qm"_s;
#ifdef Q_OS_ANDROID
    const QString path = u"assets:/share/"_s + subPath;
    return QFile::exists(path) ? path : QString();
#else
    return QStandardPaths::locate(QStandardPaths::GenericDataLocation, subPath);
#endif
}

// Keeps only the app language's catalogs. Libraries install theirs on the
// application, which sends it a LanguageChange event each time.
class CatalogSwapper : public QObject
{
public:
    CatalogSwapper(const QString &language, QObject *parent)
        : QObject(parent)
    {
        // Like ECMQmLoader: "pt_BR", else "pt" (the first one found only).
        m_languages.append(language);
        const qsizetype country = language.indexOf(u'_');
        if (country > 0) {
            m_languages.append(language.left(country));
        }
    }

    void swap()
    {
        m_busy = true; // our own (un)installs send LanguageChange too
        QList<Catalog> seen;
        for (const QString &name : KnownCatalogs) {
            seen.append({name, QString(), QString()});
        }
        seen.append({u"qt"_s, QString(), QLibraryInfo::path(QLibraryInfo::TranslationsPath)});
        QSet<QString> ours;
        QSet<QString> paths;
        const auto translators = QCoreApplication::instance()->findChildren<QTranslator *>(Qt::FindDirectChildrenOnly);
        for (QTranslator *translator : translators) {
            const Catalog catalog = catalogOf(translator->filePath());
            if (catalog.name.isEmpty()) {
                continue;
            }
            seen.append(catalog);
            const bool duplicate = paths.contains(translator->filePath());
            paths.insert(translator->filePath());
            if (m_languages.contains(catalog.language) && !duplicate) {
                ours.insert(catalog.name);
            } else {
                // Another language, the "en" plural forms every library loads
                // (only needed when the app is in English), or one loaded twice.
                QCoreApplication::removeTranslator(translator);
                translator->deleteLater();
            }
        }
        for (Catalog catalog : std::as_const(seen)) {
            if (ours.contains(catalog.name) || m_tried.contains(catalog.name)) {
                continue;
            }
            m_tried.insert(catalog.name);
            for (const QString &language : std::as_const(m_languages)) {
                catalog.language = language;
                const QString path = catalogFile(catalog);
                if (path.isEmpty()) {
                    continue;
                }
                auto *translator = new QTranslator(QCoreApplication::instance());
                if (translator->load(path)) {
                    QCoreApplication::installTranslator(translator);
                    break;
                }
                delete translator;
            }
        }
        m_busy = false;
    }

protected:
    bool eventFilter(QObject *watched, QEvent *event) override
    {
        if (event->type() == QEvent::LanguageChange && watched == QCoreApplication::instance() && !m_busy) {
            swap();
        }
        return QObject::eventFilter(watched, event);
    }

private:
    QStringList m_languages;
    QSet<QString> m_tried;
    bool m_busy = false;
};
}

void useFrameworkCatalogs(const QString &language)
{
    if (language.isEmpty()) {
        return; // the system's language: what the libraries load already
    }
    auto *swapper = new CatalogSwapper(language, QCoreApplication::instance());
    swapper->swap();
    QCoreApplication::instance()->installEventFilter(swapper);
}
