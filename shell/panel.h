/* panel/DwmPanel.qml + panel/WorkspaceButton.qml: the top panel that replaces
 * dwm-qs's built-in bar. dwm-qs reserves a strip of Theme::panelHeight px at
 * the top of each screen; this window paints into it (as an unmanaged
 * _NET_WM_WINDOW_TYPE_DOCK window). */
#ifndef DWMQS_PANEL_H
#define DWMQS_PANEL_H

#include <QPointer>
#include <QScreen>
#include <QWidget>

#include "dwmstate.h"
#include "widgets.h"

class QHBoxLayout;

class WorkspaceButton : public QWidget {
    Q_OBJECT
public:
    explicit WorkspaceButton(const QString &label, QWidget *parent = nullptr);

    void setLabel(const QString &l);
    void setStates(bool selected, bool occupied);

signals:
    void clicked();

protected:
    void paintEvent(QPaintEvent *) override;
    void enterEvent(QEnterEvent *) override;
    void leaveEvent(QEvent *) override;
    void mousePressEvent(QMouseEvent *) override;
    void mouseReleaseEvent(QMouseEvent *) override;

private:
    QString m_label;
    bool m_selected = false;
    bool m_occupied = false;
    bool m_hover = false;
    bool m_pressed = false;
};

class Panel : public QWidget {
    Q_OBJECT
public:
    Panel(DwmState *state, QScreen *screen);

    /* Max characters shown for the window title before shortening. */
    static constexpr int maxTitleLength = 45;
    static QString shortenTitle(const QString &t);

protected:
    void paintEvent(QPaintEvent *) override;

private:
    const DwmState::Monitor *mon() const;
    bool hostsTray() const;
    void applyGeometry();
    void syncFromState();

    DwmState *m_state;
    QPointer<QScreen> m_screen;

    QWidget *m_wsBox;
    QHBoxLayout *m_wsLayout;
    QVector<WorkspaceButton *> m_wsButtons;
    TextItem *m_layoutSymbol;
    TextItem *m_title;
    QWidget *m_statusBox;
    QHBoxLayout *m_statusLayout;
    QVector<TextItem *> m_statusItems;
};

#endif
