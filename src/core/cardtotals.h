// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QList>
#include <QSet>
#include <QString>
#include <QStringList>

struct CardLimitRow {
    QString id;
    QString itemId;
    QString holderType;
    double limit = 0;
    double available = 0;
};

struct CardTotals {
    double limit = 0;
    double available = 0;
    double used = 0;
    QSet<QString> counted; // cards that contribute to the totals
    QSet<QString> shared; // cards skipped because they share another card's limit

    double usedRatio() const
    {
        return limit > 0 ? used / limit : 0;
    }
};

// Overall credit limit across cards.
//
// A card is counted unless the user excluded it, it is an additional card
// (holderType ADDITIONAL), or another card of the same connection already
// reported exactly the same limit and available amount (cards sharing one
// limit, which would otherwise be counted twice).
SALDOCORE_EXPORT CardTotals computeCardTotals(const QList<CardLimitRow> &cards, const QStringList &excludedIds);
