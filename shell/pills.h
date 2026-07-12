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

/* WireGuard tun1 indicator/toggle. */
class VpnWidget : public BarPill {
    Q_OBJECT
public:
    explicit VpnWidget(QWidget *parent = nullptr);

private:
    void parse(const QString &text);
    void sync();

    bool m_up = false;
    QString m_ip;
    CollectorProcess m_statusProc;
    CollectorProcess m_toggleProc;
};

#endif
