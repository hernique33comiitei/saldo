// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QString>

namespace Categories
{
// Breeze icon name for a Pluggy category (English description, as returned in
// the transaction "category" field).
SALDOCORE_EXPORT QString iconName(const QString &category);

// Name to show for a category: Pluggy's Portuguese translation when the UI
// language is Portuguese, the English description otherwise.
SALDOCORE_EXPORT QString displayName(const QString &description, const QString &translated);

}
