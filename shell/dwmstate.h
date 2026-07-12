/* state/DwmState.qml: live dwm-qs WM state from the dwm-qs-state bridge. */
#ifndef DWMQS_DWMSTATE_H
#define DWMQS_DWMSTATE_H

#include <QObject>
#include <QStringList>
#include <QVector>

#include "procutil.h"

class DwmState : public QObject {
    Q_OBJECT
public:
    struct Monitor {
        int num = 0, x = 0, y = 0, w = 0, h = 0;
        int selMask = 0, occMask = 0;
        bool sel = false;
        QString layout;
        QString title;
    };

    explicit DwmState(QObject *parent = nullptr);

    int currentWorkspace = 0;
    int occupiedMask = 0;
    QStringList workspaceNames{"1", "2", "3", "4", "5", "6", "7", "8", "9"};
    QString layout;
    QString statusText;
    QStringList statusSegments;
    QVector<Monitor> monitors;

    void switchWorkspace(int mon, int index);

signals:
    void changed();

private:
    void parseState(const QString &text);
    void updateStatusSegments();

    BlockWatchProcess m_watch;
};

#endif
