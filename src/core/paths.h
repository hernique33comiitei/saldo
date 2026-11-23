// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QString>

// Every file location used by Saldo. Paths are explicit (not derived from the
// application name) because the Plasma widget runs inside plasmashell and must
// read the same files as the app.
namespace Paths
{
// Demo mode (SALDO_DEMO=1 or --demo) uses fake data in separate files.
SALDOCORE_EXPORT bool isDemo();
SALDOCORE_EXPORT void setDemo(bool demo);

// Tests point everything at a temporary directory.
SALDOCORE_EXPORT void setOverrideDir(const QString &dir);

SALDOCORE_EXPORT QString dataDir();
SALDOCORE_EXPORT QString databaseFile();
SALDOCORE_EXPORT QString stampFile();
SALDOCORE_EXPORT QString lockFile();
SALDOCORE_EXPORT QString configFile();
}
