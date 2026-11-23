// SPDX-License-Identifier: MIT
#include "paths.h"

#include <QDir>
#include <QFile>
#include <QStandardPaths>

using namespace Qt::StringLiterals;

namespace
{
bool s_demo = qEnvironmentVariableIntValue("SALDO_DEMO") == 1;
QString s_overrideDir;

QString ensurePrivateDir(const QString &path)
{
    QDir().mkpath(path);
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    return path;
}
}

bool Paths::isDemo()
{
    return s_demo;
}

void Paths::setDemo(bool demo)
{
    s_demo = demo;
}

void Paths::setOverrideDir(const QString &dir)
{
    s_overrideDir = dir;
}

QString Paths::dataDir()
{
    if (!s_overrideDir.isEmpty()) {
        return ensurePrivateDir(s_overrideDir);
    }
#ifdef Q_OS_ANDROID
    return ensurePrivateDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation));
#else
    return ensurePrivateDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + u"/saldo"_s);
#endif
}

QString Paths::databaseFile()
{
    return dataDir() + (s_demo ? u"/demo.sqlite"_s : u"/saldo.sqlite"_s);
}

QString Paths::stampFile()
{
    return dataDir() + (s_demo ? u"/demo.stamp"_s : u"/saldo.stamp"_s);
}

QString Paths::lockFile()
{
    return dataDir() + (s_demo ? u"/demo-sync.lock"_s : u"/sync.lock"_s);
}

QString Paths::configFile()
{
    QString dir = s_overrideDir;
    if (dir.isEmpty()) {
#ifdef Q_OS_ANDROID
        dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
#else
        dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
#endif
    }
    QDir().mkpath(dir);
    return dir + (s_demo ? u"/saldo-demorc"_s : u"/saldorc"_s);
}
