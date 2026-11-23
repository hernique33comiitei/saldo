// SPDX-License-Identifier: MIT
#include "categories.h"

#include <KLocalizedString>

#include <QList>
#include <QLocale>
#include <QStringList>

using namespace Qt::StringLiterals;

namespace
{
struct IconRule {
    QStringList keywords;
    QString icon;
};

const QList<IconRule> &iconRules()
{
    // Order matters: the first rule with a matching keyword wins.
    static const QList<IconRule> rules = {
        {{u"credit card"_s}, u"view-financial-account-credit-card-symbolic"_s},
        {{u"transfer"_s, u"pix"_s}, u"exchange-positions"_s},
        {{u"invest"_s, u"fixed income"_s, u"variable income"_s, u"pension"_s}, u"view-financial-account-investment"_s},
        {{u"income"_s, u"salary"_s, u"retirement"_s, u"wage"_s, u"benefit"_s, u"proceeds"_s}, u"view-financial-category-income"_s},
        {{u"grocer"_s, u"supermarket"_s, u"food"_s, u"restaurant"_s, u"eating"_s, u"drink"_s, u"delivery"_s, u"bakery"_s, u"coffee"_s},
         u"food"_s},
        {{u"health"_s, u"pharmac"_s, u"hospital"_s, u"dentist"_s, u"medical"_s, u"wellness"_s, u"gym"_s}, u"love"_s},
        {{u"transport"_s, u"gas station"_s, u"fuel"_s, u"taxi"_s, u"ride"_s, u"parking"_s, u"toll"_s, u"vehicle"_s, u"car"_s}, u"car"_s},
        {{u"travel"_s, u"airport"_s, u"airline"_s, u"accommodation"_s, u"hotel"_s, u"mileage"_s}, u"globe"_s},
        {{u"housing"_s, u"rent"_s, u"utilities"_s, u"electricity"_s, u"water"_s, u"condo"_s, u"home"_s}, u"go-home-symbolic"_s},
        {{u"education"_s, u"school"_s, u"university"_s, u"course"_s, u"book"_s}, u"bookmarks-symbolic"_s},
        {{u"telecom"_s, u"phone"_s, u"internet"_s, u"mobile"_s}, u"phone-symbolic"_s},
        {{u"digital"_s, u"streaming"_s, u"video"_s, u"music"_s, u"software"_s}, u"video-symbolic"_s},
        {{u"leisure"_s, u"entertainment"_s, u"gaming"_s, u"gambling"_s, u"sport"_s, u"ticket"_s}, u"input-gamepad-symbolic"_s},
        {{u"shopping"_s, u"clothing"_s, u"electronics"_s, u"store"_s, u"pet"_s}, u"amarok_cart_view-symbolic"_s},
        {{u"tax"_s, u"legal"_s}, u"taxes-finances"_s},
        {{u"bank fee"_s, u"fee"_s, u"interest"_s, u"loan"_s, u"financing"_s}, u"view-bank"_s},
        {{u"donation"_s, u"charity"_s}, u"help-donate"_s},
        {{u"insurance"_s}, u"firewall-applet-shields_up-symbolic"_s},
        {{u"service"_s}, u"view-pim-tasks"_s},
    };
    return rules;
}
}

QString Categories::iconName(const QString &category)
{
    const QString c = category.toLower();
    if (!c.isEmpty()) {
        for (const IconRule &rule : iconRules()) {
            for (const QString &keyword : rule.keywords) {
                if (c.contains(keyword)) {
                    return rule.icon;
                }
            }
        }
    }
    return u"tag-symbolic"_s;
}

QString Categories::displayName(const QString &description, const QString &translated)
{
    if (description.isEmpty() && translated.isEmpty()) {
        return i18n("Uncategorized");
    }
    if (!translated.isEmpty() && (description.isEmpty() || QLocale().language() == QLocale::Portuguese)) {
        return translated;
    }
    return description;
}
