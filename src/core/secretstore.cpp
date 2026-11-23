// SPDX-License-Identifier: MIT
#include "secretstore.h"

#include "logging.h"
#include "paths.h"

#include <KLocalizedString>

using namespace Qt::StringLiterals;

namespace
{
QString serviceName()
{
    return Paths::isDemo() ? QStringLiteral(SALDO_APP_ID ".Demo") : QStringLiteral(SALDO_APP_ID);
}

const auto SecretKey = u"pluggy-credentials"_s;
}

#ifdef SALDO_USE_QTKEYCHAIN

#include <qt6keychain/keychain.h>

SecretStore::SecretStore(QObject *parent)
    : QObject(parent)
{
}

bool SecretStore::isAvailable()
{
    return QKeychain::isAvailable();
}

QString SecretStore::unavailableReason()
{
    return i18n("No system keyring is available to store the Pluggy credentials.");
}

void SecretStore::read(ReadCallback callback)
{
    auto *job = new QKeychain::ReadPasswordJob(serviceName(), this);
    job->setKey(SecretKey);
    job->setAutoDelete(true);
    connect(job, &QKeychain::Job::finished, this, [job, callback](QKeychain::Job *) {
        if (job->error() == QKeychain::NoError) {
            callback(true, job->binaryData(), QString());
        } else if (job->error() == QKeychain::EntryNotFound) {
            callback(false, {}, QString());
        } else {
            callback(false, {}, job->errorString());
        }
    });
    job->start();
}

void SecretStore::write(const QByteArray &secret, WriteCallback callback)
{
    auto *job = new QKeychain::WritePasswordJob(serviceName(), this);
    job->setKey(SecretKey);
    job->setBinaryData(secret);
    job->setAutoDelete(true);
    connect(job, &QKeychain::Job::finished, this, [job, callback](QKeychain::Job *) {
        callback(job->error() == QKeychain::NoError, job->errorString());
    });
    job->start();
}

void SecretStore::remove(WriteCallback callback)
{
    auto *job = new QKeychain::DeletePasswordJob(serviceName(), this);
    job->setKey(SecretKey);
    job->setAutoDelete(true);
    connect(job, &QKeychain::Job::finished, this, [job, callback](QKeychain::Job *) {
        const bool ok = job->error() == QKeychain::NoError || job->error() == QKeychain::EntryNotFound;
        callback(ok, ok ? QString() : job->errorString());
    });
    job->start();
}

#else // secret-tool

#include <QProcess>
#include <QStandardPaths>

namespace
{
QString secretTool()
{
    return QStandardPaths::findExecutable(u"secret-tool"_s);
}

QStringList attributes()
{
    return {u"service"_s, serviceName(), u"account"_s, SecretKey};
}

// Runs secret-tool asynchronously and reports (exitCode, stdout, error).
void runSecretTool(QObject *context,
                   const QStringList &args,
                   const QByteArray &input,
                   std::function<void(int exitCode, const QByteArray &out, const QString &error)> done)
{
    const QString program = secretTool();
    if (program.isEmpty()) {
        done(-1, {}, SecretStore::unavailableReason());
        return;
    }

    auto *process = new QProcess(context);
    process->setProgram(program);
    process->setArguments(args);
    QObject::connect(process, &QProcess::finished, context, [process, done](int exitCode, QProcess::ExitStatus status) {
        const QByteArray out = process->readAllStandardOutput();
        const QString err = QString::fromUtf8(process->readAllStandardError()).trimmed();
        process->deleteLater();
        if (status != QProcess::NormalExit) {
            done(-1, {}, i18n("secret-tool crashed."));
            return;
        }
        done(exitCode, out, err);
    });
    QObject::connect(process, &QProcess::errorOccurred, context, [process, done](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            process->deleteLater();
            done(-1, {}, i18n("Could not start secret-tool."));
        }
    });
    process->start();
    if (!input.isNull()) {
        process->write(input);
        process->closeWriteChannel();
    }
}
}

SecretStore::SecretStore(QObject *parent)
    : QObject(parent)
{
}

bool SecretStore::isAvailable()
{
    return !secretTool().isEmpty();
}

QString SecretStore::unavailableReason()
{
    return i18n("secret-tool was not found. Install libsecret (Fedora: libsecret, Debian/Ubuntu: libsecret-tools) so Saldo can keep the Pluggy credentials in the system keyring.");
}

void SecretStore::read(ReadCallback callback)
{
    runSecretTool(this, QStringList{u"lookup"_s} + attributes(), QByteArray(), [callback](int exitCode, const QByteArray &out, const QString &error) {
        if (exitCode == 0 && !out.isEmpty()) {
            callback(true, out, QString());
        } else if (exitCode == 1 || (exitCode == 0 && out.isEmpty())) {
            callback(false, {}, QString()); // not stored yet
        } else {
            qCWarning(SALDO_LOG) << "secret-tool lookup failed:" << error;
            callback(false, {}, error);
        }
    });
}

void SecretStore::write(const QByteArray &secret, WriteCallback callback)
{
    const QStringList args = QStringList{u"store"_s, u"--label=%1"_s.arg(i18n("Saldo: Meu Pluggy credentials"))} + attributes();
    runSecretTool(this, args, secret, [callback](int exitCode, const QByteArray &, const QString &error) {
        callback(exitCode == 0, exitCode == 0 ? QString() : error);
    });
}

void SecretStore::remove(WriteCallback callback)
{
    runSecretTool(this, QStringList{u"clear"_s} + attributes(), QByteArray(), [callback](int exitCode, const QByteArray &, const QString &error) {
        // clear exits with 1 when nothing matched, which is fine.
        const bool ok = exitCode == 0 || exitCode == 1;
        callback(ok, ok ? QString() : error);
    });
}

#endif
