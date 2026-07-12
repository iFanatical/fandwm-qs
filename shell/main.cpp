/* dwm-qs-shell: hand-rolled C++/Qt replacement for the QuickShell panel.
 * One process runs the per-screen panels, popups, SNI tray, and launcher.
 *
 *   dwm-qs-shell [--no-duplicate]          run the shell
 *   dwm-qs-shell ipc call <target> <fn>    poke a running instance
 *                (targets: launcher, runner, dunst — as under quickshell) */
#include <QApplication>
#include <QHash>
#include <QScreen>

#include "dwmstate.h"
#include "ipc.h"
#include "launcher.h"
#include "panel.h"
#include "pills.h"

int main(int argc, char *argv[])
{
    /* Client mode must not need a display connection. */
    QStringList rawArgs;
    for (int i = 1; i < argc; i++)
        rawArgs << QString::fromLocal8Bit(argv[i]);
    if (!rawArgs.isEmpty() && rawArgs[0] == QLatin1String("ipc")) {
        QStringList a = rawArgs.mid(1);
        if (!a.isEmpty() && a[0] == QLatin1String("call"))
            a.removeFirst();
        if (a.size() < 2) {
            fprintf(stderr,
                    "usage: dwm-qs-shell ipc call <target> <function>\n");
            return 2;
        }
        return IpcServer::call(a[0], a[1]);
    }

    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("dwm-qs-shell"));
    app.setQuitOnLastWindowClosed(false);

    if (rawArgs.contains(QLatin1String("--no-duplicate"))
            && IpcServer::serverRunning())
        return 0;

    auto *state = new DwmState(&app);

    /* One panel per screen, following screen hot-plug. */
    QHash<QScreen *, Panel *> panels;
    auto addPanel = [&panels, state](QScreen *s) {
        if (panels.contains(s))
            return;
        auto *p = new Panel(state, s);
        panels.insert(s, p);
        p->show();
    };
    const QList<QScreen *> screens = app.screens();
    for (QScreen *s : screens)
        addPanel(s);
    QObject::connect(&app, &QGuiApplication::screenAdded, &app, addPanel);
    QObject::connect(&app, &QGuiApplication::screenRemoved, &app,
                     [&panels](QScreen *s) {
                         if (Panel *p = panels.take(s))
                             p->deleteLater();
                     });

    /* Single centered launcher on the primary monitor. */
    auto *launcher = new AppLauncher(&app);

    auto *ipc = new IpcServer(&app);
    ipc->handle(QStringLiteral("launcher"), QStringLiteral("toggle"),
                [launcher]() { launcher->toggleMode(QStringLiteral("apps")); });
    ipc->handle(QStringLiteral("launcher"), QStringLiteral("show"),
                [launcher]() { launcher->openMode(QStringLiteral("apps")); });
    ipc->handle(QStringLiteral("launcher"), QStringLiteral("hide"),
                [launcher]() { launcher->hideLauncher(); });
    ipc->handle(QStringLiteral("runner"), QStringLiteral("toggle"),
                [launcher]() { launcher->toggleMode(QStringLiteral("run")); });
    ipc->handle(QStringLiteral("runner"), QStringLiteral("show"),
                [launcher]() { launcher->openMode(QStringLiteral("run")); });
    ipc->handle(QStringLiteral("runner"), QStringLiteral("hide"),
                [launcher]() { launcher->hideLauncher(); });
    ipc->handle(QStringLiteral("dunst"), QStringLiteral("toggle"),
                []() { DunstService::instance()->toggle(); });
    ipc->handle(QStringLiteral("dunst"), QStringLiteral("refresh"),
                []() { DunstService::instance()->refresh(); });
    ipc->listen();

    return app.exec();
}
