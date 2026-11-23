// SPDX-License-Identifier: MIT

#include "config.h"
#include "paths.h"

#include <KAboutData>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include <QCommandLineParser>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

#ifdef Q_OS_ANDROID
#include <QGuiApplication>
using Application = QGuiApplication;
#else
#include <QApplication>
using Application = QApplication; // native file dialogs / widgets
#endif

using namespace Qt::StringLiterals;

int main(int argc, char *argv[])
{
    Application app(argc, argv);

#ifdef Q_OS_ANDROID
    QQuickStyle::setStyle(u"org.kde.breeze"_s);
#else
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(u"org.kde.desktop"_s);
    }
#endif

    // --demo has its own files: switch before reading any of them (the
    // language below included). The parser handles the option again later.
    if (app.arguments().contains(u"--demo"_s)) {
        Paths::setDemo(true);
    }

    KLocalizedString::setApplicationDomain("saldo");
    // The language picked in Settings, before the first i18n() call.
    if (const QString language = Config::storedLanguage(); !language.isEmpty()) {
        KLocalizedString::setLanguages({language});
    }
    QCoreApplication::setOrganizationName(u"saldo"_s);
    QCoreApplication::setApplicationName(u"saldo"_s);

    KAboutData about(u"saldo"_s,
                     i18n("Saldo"),
                     QStringLiteral(SALDO_VERSION),
                     i18n("Bank balances, card limits and transactions from Open Finance (Meu Pluggy)"),
                     KAboutLicense::MIT,
                     i18n("© 2026 Henrique Oliveira"));
    about.setDesktopFileName(QStringLiteral(SALDO_APP_ID));
    about.setHomepage(QStringLiteral(SALDO_WEBSITE));
    about.setBugAddress(QStringLiteral(SALDO_WEBSITE "/issues").toUtf8());
    about.addAuthor(QStringLiteral("Henrique Oliveira"),
                    i18n("Author"),
                    QStringLiteral("henriik.dev@gmail.com"),
                    QStringLiteral("https://github.com/hernique33comiitei"));
    about.setOtherText(i18n("Data comes from the Meu Pluggy personal-use API. Saldo is an independent open source project, not affiliated with Pluggy."));
    KAboutData::setApplicationData(about);

    // Bundled icon via qrc, so the window never resolves to a stale themed copy.
    Application::setWindowIcon(QIcon(u":/icons/saldo.svg"_s));

    QCommandLineParser parser;
    about.setupCommandLine(&parser);
    const QCommandLineOption demoOption(u"demo"_s, i18n("Show fake demo data instead of your Meu Pluggy accounts."));
    const QCommandLineOption pageOption(u"page"_s,
                                        i18n("Page to open: overview, accounts, cards, transactions, investments, settings, setup or about."),
                                        i18nc("command line value name", "page"));
    parser.addOption(demoOption);
    parser.addOption(pageOption);
    parser.process(app);
    about.processCommandLine(&parser);

    // Must happen before any core singleton opens its files.
    if (parser.isSet(demoOption)) {
        Paths::setDemo(true);
    }

    QQmlApplicationEngine engine;
    KLocalization::setupLocalizedContext(&engine);
    engine.setInitialProperties({{u"initialPage"_s, parser.value(pageOption)}});
    engine.loadFromModule("org.saldo", "Main");
    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    // Development aid (AppStream screenshots, visual checks):
    // SALDO_SCREENSHOT=/path/file.png saldo --demo --page cards
    const QString screenshot = qEnvironmentVariable("SALDO_SCREENSHOT");
    if (!screenshot.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        const QStringList size = qEnvironmentVariable("SALDO_SCREENSHOT_SIZE").split(u'x'); // e.g. 1100x900
        if (window && size.size() == 2) {
            window->resize(size.at(0).toInt(), size.at(1).toInt());
        }
        QTimer::singleShot(qEnvironmentVariableIntValue("SALDO_SCREENSHOT_DELAY") > 0 ? qEnvironmentVariableIntValue("SALDO_SCREENSHOT_DELAY") : 2500, &app, [window, screenshot]() {
            if (window) {
                window->grabWindow().save(screenshot);
            }
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
