// SPDX-License-Identifier: MIT
#pragma once

#include "rowlistmodel.h"

// Transactions, newest first, loaded page by page from the cache.
class SALDOCORE_EXPORT TransactionsModel : public RowListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString accountId READ accountId WRITE setAccountId NOTIFY filterChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY filterChanged)
    // "yyyy-MM" or empty for all months
    Q_PROPERTY(QString month READ month WRITE setMonth NOTIFY filterChanged)
    Q_PROPERTY(Kind kind READ kind WRITE setKind NOTIFY filterChanged)
    // When > 0, only that many rows (widget); otherwise pages of 100 + loadMore()
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY filterChanged)
    Q_PROPERTY(bool canLoadMore READ canLoadMore NOTIFY summaryChanged)
    Q_PROPERTY(double totalIncome READ totalIncome NOTIFY summaryChanged)
    Q_PROPERTY(double totalExpense READ totalExpense NOTIFY summaryChanged)

public:
    enum Kind {
        All,
        Income,
        Expense,
    };
    Q_ENUM(Kind)

    explicit TransactionsModel(QObject *parent = nullptr);

    QString accountId() const;
    void setAccountId(const QString &id);
    QString searchText() const;
    void setSearchText(const QString &text);
    QString month() const;
    void setMonth(const QString &month);
    Kind kind() const;
    void setKind(Kind kind);
    int limit() const;
    void setLimit(int limit);
    bool canLoadMore() const;
    double totalIncome() const;
    double totalExpense() const;

    Q_INVOKABLE void loadMore();
    // 1 = transfer between my accounts, 0 = counts as income/expense,
    // -1 = back to automatic detection.
    Q_INVOKABLE void setInternal(const QString &transactionId, int value);

Q_SIGNALS:
    void filterChanged();

protected:
    QList<QVariantMap> fetchRows() override;

private:
    QList<QVariantMap> query(int limit, int offset);
    void computeTotals();

    QString m_accountId;
    QString m_searchText;
    QString m_month;
    Kind m_kind = All;
    int m_limit = 0;
    int m_loaded = 0;
    bool m_canLoadMore = false;
    double m_totalIncome = 0;
    double m_totalExpense = 0;
};
