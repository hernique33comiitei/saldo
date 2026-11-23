// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QStringList>

// Fake but realistic data for demo mode (SALDO_DEMO=1 / --demo): lets the UI
// be explored and screenshotted without Pluggy credentials.
namespace DemoData
{
SALDOCORE_EXPORT bool populate();
// The demo's two connections; Config uses them as the demo's item IDs so the
// demo looks set up (no "Connect Meu Pluggy" entry, no "not connected" banner).
SALDOCORE_EXPORT QStringList itemIds();
}
