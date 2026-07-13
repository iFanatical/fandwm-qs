#include "panel.h"

#include <QEnterEvent>
#include <QGuiApplication>
#include <QHBoxLayout>
#include <QMouseEvent>
#include <QPainter>

#include "bluetooth.h"
#include "calendar.h"
#include "network.h"
#include "pills.h"
#include "tray.h"
#include "volume.h"
#include "x11util.h"

/* --------------------------------------------------------- WorkspaceButton */

WorkspaceButton::WorkspaceButton(const QString &label, QWidget *parent)
    : QWidget(parent), m_label(label)
{
    setFixedSize(Theme::workspaceButtonSize, Theme::workspaceButtonSize);
    setCursor(Qt::PointingHandCursor);
    setMouseTracking(true);
}

void WorkspaceButton::setLabel(const QString &l)
{
    if (m_label == l)
        return;
    m_label = l;
    update();
}

void WorkspaceButton::setStates(bool selected, bool occupied)
{
    if (m_selected == selected && m_occupied == occupied)
        return;
    m_selected = selected;
    m_occupied = occupied;
    update();
}

void WorkspaceButton::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    const QColor fill = m_selected
                            ? Theme::surface
                            : (m_hover ? Theme::surfaceHover
                                       : Theme::transparent);
    Theme::paintRect(p, rect(), fill, Theme::smallRadius);
    /* active = cyan, has windows = white, empty = gray */
    p.setFont(Theme::font(Theme::panelFontSize, m_selected || m_occupied));
    p.setPen(m_selected ? Theme::tagActive
                        : (m_occupied ? Theme::tagOccupied : Theme::tagEmpty));
    p.drawText(rect(), Qt::AlignCenter, m_label);
}

void WorkspaceButton::enterEvent(QEnterEvent *)
{
    m_hover = true;
    update();
}

void WorkspaceButton::leaveEvent(QEvent *)
{
    m_hover = false;
    update();
}

void WorkspaceButton::mousePressEvent(QMouseEvent *e)
{
    if (e->button() == Qt::LeftButton)
        m_pressed = true;
}

void WorkspaceButton::mouseReleaseEvent(QMouseEvent *e)
{
    if (m_pressed && e->button() == Qt::LeftButton && rect().contains(e->pos()))
        emit clicked();
    m_pressed = false;
}

/* ------------------------------------------------------------------- Panel */

Panel::Panel(DwmState *state, QScreen *screen)
    : QWidget(nullptr, Qt::Window | Qt::FramelessWindowHint),
      m_state(state), m_screen(screen)
{
    setAttribute(Qt::WA_ShowWithoutActivating);

    auto *row = new QHBoxLayout(this);
    row->setContentsMargins(Theme::panelPadding, 0, Theme::panelPadding, 0);
    row->setSpacing(Theme::rowSpacing);

    /* Workspaces (dwm tags) */
    m_wsBox = new QWidget(this);
    m_wsLayout = new QHBoxLayout(m_wsBox);
    m_wsLayout->setContentsMargins(0, 0, 0, 0);
    m_wsLayout->setSpacing(Theme::rowSpacing);
    row->addWidget(m_wsBox, 0, Qt::AlignVCenter);

    /* Active layout symbol (e.g. []=, [M], [3]) — per monitor */
    m_layoutSymbol = new TextItem(this);
    m_layoutSymbol->setColor(Theme::accent);
    m_layoutSymbol->setBold(true);
    row->addWidget(m_layoutSymbol, 0, Qt::AlignVCenter);

    /* Focused window title, elided, fills the middle gap */
    m_title = new TextItem(this);
    m_title->setColor(Theme::magenta);
    m_title->setElide(true);
    row->addWidget(m_title, 1, Qt::AlignVCenter);

    /* Optional status segments (from root WM_NAME, dwmblocks-style) */
    m_statusBox = new QWidget(this);
    m_statusLayout = new QHBoxLayout(m_statusBox);
    m_statusLayout->setContentsMargins(0, 0, 0, 0);
    m_statusLayout->setSpacing(Theme::rowSpacing);
    row->addWidget(m_statusBox, 0, Qt::AlignVCenter);

    /* Status/control widgets */
    row->addWidget(new DunstWidget(this), 0, Qt::AlignVCenter);
    row->addWidget(new NetworkWidget(this), 0, Qt::AlignVCenter);
    auto *mem = new ScriptPill({"dwm-qs-mem"}, 5000, this);
    mem->setFixedTint(Theme::brightyellow);
    row->addWidget(mem, 0, Qt::AlignVCenter);
    row->addWidget(new VpnWidget(this), 0, Qt::AlignVCenter);
    row->addWidget(new VolumeWidget(this), 0, Qt::AlignVCenter);
    row->addWidget(new ScriptPill({"dwm-qs-battery"}, 15000, this), 0,
                   Qt::AlignVCenter);
    row->addWidget(new BluetoothWidget(this), 0, Qt::AlignVCenter);
    auto *tray = new TrayArea(this);
    row->addWidget(tray, 0, Qt::AlignVCenter);
    row->addWidget(new ClockWidget(this), 0, Qt::AlignVCenter);

    /* Tray shows on this screen only if it is the tray host; re-evaluated on
     * monitor hot-plug (DwmPanel.qml showTray). */
    auto updateTrayHost = [this, tray]() { tray->setHostsTray(hostsTray()); };
    updateTrayHost();
    connect(qApp, &QGuiApplication::screenAdded, tray, updateTrayHost);
    connect(qApp, &QGuiApplication::screenRemoved, tray, updateTrayHost);

    connect(m_state, &DwmState::changed, this, &Panel::syncFromState);
    if (screen) {
        connect(screen, &QScreen::geometryChanged, this,
                [this]() { applyGeometry(); });
    }

    applyGeometry();
    syncFromState();

    /* Create the native window and mark it as a dock before it is mapped so
     * dwm-qs leaves it unmanaged. */
    winId();
    X11Util::setDock(winId());
}

/* Tray shows on this screen if its name is listed in Theme::primaryScreens;
 * if none of the listed names are connected, fall back to the first screen.
 * Lets one list serve multiple machines (laptop vs desktop). */
bool Panel::hostsTray() const
{
    if (!m_screen)
        return false;
    for (const QString &n : Theme::primaryScreens)
        if (m_screen->name() == n)
            return true;
    const QList<QScreen *> screens = QGuiApplication::screens();
    for (const QString &n : Theme::primaryScreens)
        for (QScreen *s : screens)
            if (s->name() == n)
                return false; /* a listed output exists elsewhere -> not us */
    return !screens.isEmpty() && m_screen->name() == screens.first()->name();
}

void Panel::applyGeometry()
{
    if (!m_screen)
        return;
    const QRect g = m_screen->geometry();
    setFixedSize(g.width(), Theme::panelHeight);
    move(g.topLeft());
}

const DwmState::Monitor *Panel::mon() const
{
    if (!m_screen || m_state->monitors.isEmpty())
        return m_state->monitors.isEmpty() ? nullptr : &m_state->monitors[0];
    const QRect g = m_screen->geometry();
    for (const DwmState::Monitor &m : m_state->monitors)
        if (m.x == g.x() && m.y == g.y())
            return &m;
    return &m_state->monitors[0];
}

QString Panel::shortenTitle(const QString &t)
{
    const int max = maxTitleLength;
    if (t.length() <= max)
        return t;
    const QString ell = QStringLiteral("…");
    const QString sep = QStringLiteral(" - ");
    const int idx = t.lastIndexOf(sep);
    auto rstrip = [](QString s) {
        while (!s.isEmpty() && s.back().isSpace())
            s.chop(1);
        return s;
    };
    if (idx > 0) {
        const QString suffix = t.mid(idx); /* " - Mozilla Firefox" */
        const int budget = max - suffix.length() - ell.length();
        if (budget >= 1)
            return rstrip(t.left(budget)) + ell + suffix;
    }
    return rstrip(t.left(max - ell.length())) + ell;
}

void Panel::syncFromState()
{
    const DwmState::Monitor *m = mon();

    /* Workspaces: rebuild when the tag list changes, else just restyle. */
    const QStringList &names = m_state->workspaceNames;
    if (m_wsButtons.size() != names.size()) {
        qDeleteAll(m_wsButtons);
        m_wsButtons.clear();
        for (int i = 0; i < names.size(); i++) {
            auto *b = new WorkspaceButton(names[i], m_wsBox);
            m_wsLayout->addWidget(b, 0, Qt::AlignVCenter);
            connect(b, &WorkspaceButton::clicked, this, [this, i]() {
                const DwmState::Monitor *mm = mon();
                m_state->switchWorkspace(mm ? mm->num : 0, i);
            });
            m_wsButtons.push_back(b);
            b->show();
        }
    }
    for (int i = 0; i < m_wsButtons.size(); i++) {
        m_wsButtons[i]->setLabel(names[i]);
        const bool sel = m ? (m->selMask & (1 << i)) != 0
                           : i == m_state->currentWorkspace;
        const bool occ = m ? (m->occMask & (1 << i)) != 0
                           : (m_state->occupiedMask & (1 << i)) != 0;
        m_wsButtons[i]->setStates(sel, occ);
    }
    m_wsBox->setVisible(!m_wsButtons.isEmpty());

    const QString lay = m ? m->layout : m_state->layout;
    m_layoutSymbol->setText(lay);
    m_layoutSymbol->setVisible(!lay.isEmpty());

    const QString title = m ? m->title : QString();
    m_title->setText(title.isEmpty()
                         ? QString()
                         : QStringLiteral(" [ ") + shortenTitle(title)
                               + QStringLiteral(" ]"));

    /* Status segments */
    const QStringList &segs = m_state->statusSegments;
    if (m_statusItems.size() != segs.size()) {
        qDeleteAll(m_statusItems);
        m_statusItems.clear();
        for (int i = 0; i < segs.size(); i++) {
            auto *t = new TextItem(m_statusBox);
            t->setColor(Theme::textMuted);
            m_statusLayout->addWidget(t, 0, Qt::AlignVCenter);
            m_statusItems.push_back(t);
            t->show();
        }
    }
    for (int i = 0; i < m_statusItems.size(); i++)
        m_statusItems[i]->setText(segs[i]);
    m_statusBox->setVisible(!m_statusItems.isEmpty());
}

void Panel::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), Theme::bg);
}
