// SPDX-License-Identifier: MIT
#include "androidtheme.h"

#include "config.h"

#include <KColorSchemeManager>
#include <QGuiApplication>
#include <QStyleHints>

using namespace Qt::StringLiterals;

void followColorScheme(const QString &forced)
{
    auto *hints = QGuiApplication::styleHints();
    auto *schemes = KColorSchemeManager::instance();
    schemes->setAutosaveChanges(false); // the choice lives in Config.theme

    // Settings -> the color scheme Qt reports and gives the system bars'
    // icons (Unknown = the system's, updated when it changes).
    auto request = [hints, forced]() {
        const QString theme = forced.isEmpty() ? Config::instance()->theme() : forced;
        hints->setColorScheme(theme == "dark"_L1        ? Qt::ColorScheme::Dark
                                  : theme == "light"_L1 ? Qt::ColorScheme::Light
                                                        : Qt::ColorScheme::Unknown);
    };
    // That color scheme -> Kirigami's colors (the Breeze style's Kirigami
    // theme reads the active KColorScheme).
    auto apply = [hints, schemes]() {
        const bool dark = hints->colorScheme() == Qt::ColorScheme::Dark;
        schemes->activateSchemeId(dark ? u"BreezeDark"_s : u"BreezeLight"_s);
    };
    QObject::connect(hints, &QStyleHints::colorSchemeChanged, schemes, apply);
    QObject::connect(Config::instance(), &Config::themeChanged, schemes, request);
    request();
    apply();
}
