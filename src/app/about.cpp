// SPDX-License-Identifier: MIT
#include "about.h"

About::About(QObject *parent)
    : QObject(parent)
{
}

KAboutData About::aboutData() const
{
    return KAboutData::applicationData();
}
