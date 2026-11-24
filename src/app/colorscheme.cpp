// SPDX-License-Identifier: MIT
#include "colorscheme.h"

#include "config.h"

#include <KColorSchemeManager>
#include <QGuiApplication>
#include <QModelIndex>
#include <QStyleHints>

#include <memory>

using namespace Qt::StringLiterals;

void followColorScheme(const QString &forced)
{
    auto *hints = QGuiApplication::styleHints();
    // Created only when a scheme is activated: on creation it may pick a Breeze
    // scheme by itself (outside KDE's platform theme), and Plasma's own scheme
    // must stay untouched unless the user picks Light or Dark.
    auto schemes = []() {
        auto *manager = KColorSchemeManager::instance();
        manager->setAutosaveChanges(false); // the choice lives in Config.theme
        return manager;
    };

#ifdef Q_OS_ANDROID
    const bool plasma = false;
#else
    const bool plasma = qEnvironmentVariable("XDG_CURRENT_DESKTOP").split(u':').contains(u"KDE"_s, Qt::CaseInsensitive);
#endif
    auto theme = [forced]() {
        return forced.isEmpty() ? Config::instance()->theme() : forced;
    };

    // Settings -> the light/dark scheme Qt reports (Unknown = the system's,
    // updated when it changes); on Android it also sets the system bars'
    // icons. Plasma's platform theme keeps its own.
    auto request = [hints, theme, plasma]() {
        if (plasma) {
            return;
        }
        const QString name = theme();
        hints->setColorScheme(name == "dark"_L1        ? Qt::ColorScheme::Dark
                                  : name == "light"_L1 ? Qt::ColorScheme::Light
                                                       : Qt::ColorScheme::Unknown);
    };
    // -> Kirigami's colors (its theme reads the active KColorScheme).
    auto replaced = std::make_shared<bool>(false);
    auto apply = [hints, schemes, theme, plasma, replaced]() {
        const QString name = theme();
        const bool forcedLight = name == "light"_L1;
        const bool forcedDark = name == "dark"_L1;
        if (plasma && !forcedLight && !forcedDark) {
            // Plasma's own scheme, whatever it is: only undo a choice made
            // while the app runs, never touch it at startup.
            if (*replaced) {
                schemes()->activateScheme(QModelIndex());
                *replaced = false;
            }
            return;
        }
        // Light or Dark as picked (not every platform theme takes Qt's
        // request); "System" asks Qt, which reports the desktop's dark mode.
        const bool dark = forcedDark || (!forcedLight && hints->colorScheme() == Qt::ColorScheme::Dark);
        schemes()->activateSchemeId(dark ? u"BreezeDark"_s : u"BreezeLight"_s);
        *replaced = true;
    };
    QObject::connect(hints, &QStyleHints::colorSchemeChanged, qApp, apply);
    QObject::connect(Config::instance(), &Config::themeChanged, qApp, [request, apply]() {
        request();
        apply();
    });
    request();
    apply();
}
