#include "dwmstate.h"

#include <QProcess>
#include <QRegularExpression>

DwmState::DwmState(QObject *parent)
    : QObject(parent), m_watch({"dwm-qs-state", "watch"})
{
    connect(&m_watch, &BlockWatchProcess::block, this, &DwmState::parseState);
    m_watch.start();
}

void DwmState::switchWorkspace(int mon, int index)
{
    QProcess::startDetached("dwm-qs-state",
                            {"switch", QString::number(mon),
                             QString::number(index)});
}

void DwmState::parseState(const QString &text)
{
    const QStringList lines = text.trimmed().split('\n');
    QVector<Monitor> mons;
    for (const QString &line : lines) {
        if (line.startsWith(QLatin1String("monitor\t"))) {
            const QStringList f = line.mid(8).trimmed().split(
                QRegularExpression("\\s+"));
            if (f.size() >= 9) {
                Monitor m;
                m.num = f[0].toInt();
                m.x = f[1].toInt();
                m.y = f[2].toInt();
                m.w = f[3].toInt();
                m.h = f[4].toInt();
                m.selMask = f[5].toInt();
                m.occMask = f[6].toInt();
                m.sel = f[7] == QLatin1String("1");
                /* Layout is a single space-free token; the title is the
                 * remainder and may contain spaces. */
                m.layout = f[8];
                m.title = QStringList(f.mid(9)).join(' ');
                mons.push_back(m);
            }
            continue;
        }
        const int sep = line.indexOf('=');
        if (sep < 0)
            continue;
        const QString key = line.left(sep);
        const QString value = line.mid(sep + 1);
        if (key == QLatin1String("current")) {
            currentWorkspace = value.toInt();
        } else if (key == QLatin1String("occupied")) {
            occupiedMask = value.toInt();
        } else if (key == QLatin1String("names")) {
            workspaceNames = value.isEmpty() ? QStringList()
                                             : value.split('|');
        } else if (key == QLatin1String("layout")) {
            layout = value;
        } else if (key == QLatin1String("status")) {
            statusText = value;
            updateStatusSegments();
        }
    }
    if (!mons.isEmpty())
        monitors = mons;
    emit changed();
}

void DwmState::updateStatusSegments()
{
    /* Strip dwmblocks / statuscmd color markup (^c#rrggbb^, ^b^, ^d^, ^f20^,
     * ^r0,0,5,5^ ...). */
    QString text = statusText;
    text.remove(QRegularExpression("\\^[^^]*\\^"));
    text = text.trimmed();
    statusSegments.clear();
    if (text.isEmpty() || text.startsWith(QLatin1String("dwm-")))
        return;
    const QStringList parts =
        text.split(QRegularExpression("\\s+\\|\\s+| {2,}"));
    for (const QString &s : parts)
        if (!s.trimmed().isEmpty())
            statusSegments << s;
}
