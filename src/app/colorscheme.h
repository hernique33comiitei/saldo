// SPDX-License-Identifier: MIT
#pragma once

#include <QString>

// The app's colors: Breeze Light or Breeze Dark following Config.theme ("" =
// the system's, "light" or "dark"); KColorScheme carries both schemes, so this
// works without Plasma too. "" means: on Android, the phone's dark mode (Qt also
// sets the system bars' icons from it); on Plasma, Plasma's own color scheme,
// untouched and followed live by KDE's platform theme; elsewhere (GNOME), the
// desktop's dark mode. `forced` ("system", "light" or "dark", from --theme)
// replaces the setting for this run. The Plasma widget always follows Plasma.
void followColorScheme(const QString &forced = QString());
