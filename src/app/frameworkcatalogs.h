// SPDX-License-Identifier: MIT
#pragma once

#include <QString>

// KDE Frameworks translate their own texts (Kirigami's "Search…" and
// "Open drawer", the style's text menu, KCoreAddons…) with Qt catalogs that
// each library loads for the *system* language when it loads, which for
// Kirigami and the style is when QML first imports them. With a language picked
// in Settings, this swaps every such catalog for that language's, now and for
// libraries loaded later, so the whole window speaks the app's language.
void useFrameworkCatalogs(const QString &language);
