// SPDX-License-Identifier: MIT
#include "cardtotals.h"

#include <cmath>

using namespace Qt::StringLiterals;

CardTotals computeCardTotals(const QList<CardLimitRow> &cards, const QStringList &excludedIds)
{
    CardTotals totals;
    QSet<QString> seenLimits;
    for (const CardLimitRow &card : cards) {
        if (excludedIds.contains(card.id)) {
            continue;
        }
        if (card.holderType == "ADDITIONAL"_L1) {
            totals.shared.insert(card.id);
            continue;
        }
        if (card.limit > 0) {
            const QString key = u"%1|%2|%3"_s.arg(card.itemId).arg(std::llround(card.limit * 100)).arg(std::llround(card.available * 100));
            if (seenLimits.contains(key)) {
                totals.shared.insert(card.id);
                continue;
            }
            seenLimits.insert(key);
        }
        totals.counted.insert(card.id);
        totals.limit += card.limit;
        totals.available += card.available;
        totals.used += std::max(0.0, card.limit - card.available);
    }
    return totals;
}
