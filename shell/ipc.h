/* IPC mirroring `quickshell ipc call <target> <function>`:
 *   dwm-qs-shell ipc call launcher toggle|show|hide
 *   dwm-qs-shell ipc call runner   toggle|show|hide
 *   dwm-qs-shell ipc call dunst    toggle|refresh
 * A QLocalServer on $XDG_RUNTIME_DIR keyed by $DISPLAY. */
#ifndef DWMQS_IPC_H
#define DWMQS_IPC_H

#include <QLocalServer>
#include <QMap>
#include <QObject>

#include <functional>

class IpcServer : public QObject {
    Q_OBJECT
public:
    explicit IpcServer(QObject *parent = nullptr);

    bool listen();
    void handle(const QString &target, const QString &function,
                std::function<void()> fn);

    static QString socketPath();
    /* Client side; returns process exit code. */
    static int call(const QString &target, const QString &function);
    static bool serverRunning();

private:
    QLocalServer m_server;
    QMap<QString, QMap<QString, std::function<void()>>> m_handlers;
};

#endif
