// SPDX-License-Identifier: MIT
#include "launcher.h"

#include "paths.h"

#include <QFileInfo>
#include <QStandardPaths>
#ifndef Q_OS_ANDROID
#include <QProcess>
#endif

using namespace Qt::StringLiterals;

namespace
{
QString appBinary()
{
    // plasmashell's PATH may not contain ~/.local/bin, so prefer the install path.
    const QString installed = QStringLiteral(SALDO_INSTALL_BINDIR "/saldo");
    if (QFileInfo(installed).isExecutable()) {
        return installed;
    }
    return QStandardPaths::findExecutable(u"saldo"_s);
}
}

Launcher::Launcher(QObject *parent)
    : QObject(parent)
{
}

bool Launcher::canOpenApp() const
{
#ifdef Q_OS_ANDROID
    return false;
#else
    return !appBinary().isEmpty();
#endif
}

bool Launcher::openApp(const QString &page) const
{
#ifdef Q_OS_ANDROID
    Q_UNUSED(page)
    return false;
#else
    const QString binary = appBinary();
    if (binary.isEmpty()) {
        return false;
    }
    QStringList args;
    if (!page.isEmpty()) {
        args << u"--page"_s << page;
    }
    if (Paths::isDemo()) {
        args << u"--demo"_s;
    }
    return QProcess::startDetached(binary, args);
#endif
}
