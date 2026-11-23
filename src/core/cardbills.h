// SPDX-License-Identifier: MIT
#pragma once

#include "saldocore_export.h"

#include <QDate>
#include <QString>

// What a credit card has to be paid, as opposed to how much of its limit is
// used. Pluggy's account "balance" for a card is the whole outstanding debt
// (future installments included); its creditData dates are those of the LAST
// CLOSED bill. The bill that is still open is not a /bills object yet: it is
// made of the card transactions that have no billId (Pluggy marks them
// PENDING), including installments that keep the original purchase date.
struct CardBill {
    // Open bill (current cycle, not closed yet).
    bool known = false; // false when the institution gives neither bills nor billIds
    double open = 0;
    QDate openClosing; // estimated: last closing + 1 month
    QDate openDue; // estimated: last due date + 1 month

    // Last closed bill, and what is still to pay on it while it is not due.
    double lastTotal = 0;
    QDate lastClosing;
    QDate lastDue;
    double lastUnpaid = 0; // last bill minus the money paid into the card since it closed
    double closedToPay = 0; // lastUnpaid while lastDue >= today, else 0

    bool lastPaid() const
    {
        return lastTotal > 0.005 && lastUnpaid < 0.005;
    }
    // Due date passed and no payment covering the bill showed up (yet: a
    // payment made on the due date only reaches Pluggy on the next refresh).
    // Not added to toPay(), so a payment Pluggy never lists cannot inflate it.
    bool lastOverdue() const
    {
        return lastUnpaid >= 0.005 && lastDue.isValid() && lastDue < QDate::currentDate();
    }

    double toPay() const
    {
        return open + closedToPay;
    }
    QDate nextDue() const
    {
        return closedToPay > 0.005 ? lastDue : openDue;
    }
};

// creditCloseDate/creditDueDate: the card's creditData dates, used when the
// institution has no bill history.
SALDOCORE_EXPORT CardBill computeCardBill(const QString &accountId, const QDate &creditCloseDate, const QDate &creditDueDate);
