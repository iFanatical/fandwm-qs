/* core/ScriptPill.qml, core/DunstService.qml + panel/DunstWidget.qml,
 * panel/VpnWidget.qml */
#ifndef DWMQS_PILLS_H
#define DWMQS_PILLS_H

#include "procutil.h"
#include "widgets.h"

/* A read-only bar pill fed by a script that prints `icon=`, `text=`, and
 * optional `color=` lines. Polled on `interval`. Hides when it prints
 * nothing. */
class ScriptPill : public BarPill {
    Q_OBJECT
public:
    explicit ScriptPill(const QStringList &command, int intervalMs,
                        QWidget *parent = nullptr);

    /* QML `ScriptPill { tint: ... }` overrides the color= line entirely. */
    void setFixedTint(const QColor &c);

private:
    void parse(const QString &out);

    CollectorProcess m_proc;
    QColor m_fixedTint;
    bool m_hasFixedTint = false;
};

/* Dunst state, refreshed via IPC (no polling). */
class DunstService : public QObject {
    Q_OBJECT
public:
    static DunstService *instance();

    bool paused = false;
    int count = 0;

    void refresh();
    void toggle();

signals:
    void changed();

private:
    explicit DunstService(QObject *parent = nullptr);
    void parse(const QString &text);

    CollectorProcess m_statusProc;
    CollectorProcess m_toggleProc;
};

/* Dunst do-not-disturb toggle pill. */
class DunstWidget : public BarPill {
    Q_OBJECT
public:
    explicit DunstWidget(QWidget *parent = nullptr);

private:
    void sync();
};

/* WireGuard tun1 state (dwm-qs-vpn). No polling: the status is read once at
 * startup and refreshed whenever it is toggled — via the pill or
 * `dwm-qs-shell ipc call vpn toggle`. Singleton so every panel's pill and
 * the IPC handler share one state. */
class VpnState : public QObject {
    Q_OBJECT
public:
    static VpnState *instance();

    bool up = false;
    QString ip;

    void refresh();
    void toggle();

signals:
    void changed();

private:
    explicit VpnState(QObject *parent = nullptr);
    void parse(const QString &text);

    CollectorProcess m_statusProc;
    CollectorProcess m_toggleProc;
};

/* WireGuard indicator/toggle pill. Click = toggle, right-click = refresh. */
class VpnWidget : public BarPill {
    Q_OBJECT
public:
    explicit VpnWidget(QWidget *parent = nullptr);

private:
    void sync();
};

#endif
