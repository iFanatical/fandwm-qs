#include "procutil.h"

CollectorProcess::CollectorProcess(QObject *parent) : QObject(parent)
{
    m_proc.setProcessChannelMode(QProcess::SeparateChannels);
    connect(&m_proc, &QProcess::finished, this, [this]() {
        emit finished(QString::fromUtf8(m_proc.readAllStandardOutput()));
    });
}

void CollectorProcess::start()
{
    if (m_cmd.isEmpty() || m_proc.state() != QProcess::NotRunning)
        return;
    m_proc.start(m_cmd.first(), m_cmd.mid(1));
}

void CollectorProcess::start(const QStringList &cmd)
{
    if (m_proc.state() != QProcess::NotRunning)
        return;
    m_cmd = cmd;
    start();
}

BlockWatchProcess::BlockWatchProcess(const QStringList &cmd,
                                     const QByteArray &marker, QObject *parent)
    : QObject(parent), m_cmd(cmd), m_marker(marker)
{
    connect(&m_proc, &QProcess::readyReadStandardOutput, this,
            &BlockWatchProcess::onReadyRead);
}

void BlockWatchProcess::start()
{
    if (m_cmd.isEmpty() || m_proc.state() != QProcess::NotRunning)
        return;
    m_proc.start(m_cmd.first(), m_cmd.mid(1));
}

void BlockWatchProcess::onReadyRead()
{
    m_buf += m_proc.readAllStandardOutput();
    int idx;
    while ((idx = m_buf.indexOf(m_marker)) >= 0) {
        const QByteArray chunk = m_buf.left(idx);
        m_buf.remove(0, idx + m_marker.size());
        if (!chunk.trimmed().isEmpty())
            emit block(QString::fromUtf8(chunk));
    }
}
