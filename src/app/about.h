// SPDX-License-Identifier: MIT
#pragma once

#include <KAboutData>

#include <QObject>
#include <QQmlEngine>

// Exposes the application's KAboutData to the About page.
class About : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(KAboutData aboutData READ aboutData CONSTANT)

public:
    explicit About(QObject *parent = nullptr);

    KAboutData aboutData() const;
};
