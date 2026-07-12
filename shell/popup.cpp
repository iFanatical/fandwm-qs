#include "popup.h"

#include <QGuiApplication>
#include <QKeyEvent>
#include <QLayout>
#include <QPainter>
#include <QScreen>
#include <QVBoxLayout>

#include "theme.h"
#include "x11util.h"

/* Visible grabbing popups, most recent last; the topmost holds the X grab. */
static QList<QPointer<ShellPopup>> g_grabStack;
static ShellPopup *g_current = nullptr;

namespace PopupManager {

void opened(ShellPopup *p)
{
    if (g_current && g_current != p && g_current->isVisible())
        g_current->closePopup();
    g_current = p;
}

void closed(ShellPopup *p)
{
    if (g_current == p)
        g_current = nullptr;
}

} /* namespace PopupManager */

ShellPopup::ShellPopup(QWidget *anchor, int popupWidth)
    : QWidget(nullptr,
              Qt::Window | Qt::FramelessWindowHint
                  | Qt::X11BypassWindowManagerHint | Qt::WindowStaysOnTopHint),
      m_anchor(anchor), m_width(popupWidth)
{
    setAttribute(Qt::WA_TranslucentBackground);
    setAttribute(Qt::WA_ShowWithoutActivating);
}

void ShellPopup::setAnchorOffset(const QPoint &rel)
{
    m_rel = rel;
    m_hasRel = true;
}

void ShellPopup::setPopupWidth(int w)
{
    m_width = w;
}

int ShellPopup::popupHeight() const
{
    return layout() ? layout()->sizeHint().height() : height();
}

void ShellPopup::relayout()
{
    setFixedSize(m_width, popupHeight());
    if (!m_anchor)
        return;
    const QPoint rel = m_hasRel ? m_rel : QPoint(0, m_anchor->height() + 4);
    QPoint g = m_anchor->mapToGlobal(rel);
    /* Slide to stay on the anchor's screen (quickshell anchor adjustment). */
    QScreen *scr = m_anchor->screen();
    if (scr) {
        const QRect sg = scr->geometry();
        g.setX(qMax(sg.left(), qMin(g.x(), sg.right() + 1 - width())));
        g.setY(qMax(sg.top(), qMin(g.y(), sg.bottom() + 1 - height())));
    }
    move(g);
}

void ShellPopup::openPopup()
{
    relayout();
    show();
    raise();
}

void ShellPopup::closePopup()
{
    hide();
}

void ShellPopup::togglePopup()
{
    if (isVisible())
        closePopup();
    else
        openPopup();
}

void ShellPopup::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    Theme::paintRect(p, rect(), Theme::bg, Theme::radius, Theme::border, 1);
}

void ShellPopup::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Escape) {
        closePopup();
        return;
    }
    QWidget::keyPressEvent(e);
}

void ShellPopup::showEvent(QShowEvent *e)
{
    QWidget::showEvent(e);
    if (m_manageAsTopLevel)
        PopupManager::opened(this);
    g_grabStack.removeAll(this);
    g_grabStack.append(this);
    X11Util::grabKeyboard(winId());
    emit popupVisibleChanged(true);
}

ContentPopup::ContentPopup(QWidget *anchor, int popupWidth, int maxHeight)
    : ShellPopup(anchor, popupWidth), m_maxHeight(maxHeight)
{
    m_body = new QWidget(this);
    m_bodyLayout = new QVBoxLayout(m_body);
    m_bodyLayout->setContentsMargins(Theme::popupMargin, Theme::popupMargin,
                                     Theme::popupMargin, Theme::popupMargin);
    m_bodyLayout->setSpacing(Theme::popupSpacing);
    m_body->show();
}

int ContentPopup::popupHeight() const
{
    const int h = m_body->sizeHint().height();
    return m_maxHeight > 0 ? qMin(m_maxHeight, h) : h;
}

void ContentPopup::resizeEvent(QResizeEvent *e)
{
    ShellPopup::resizeEvent(e);
    /* Full content height; anything past the popup's clamped height clips. */
    m_body->setGeometry(0, 0, width(), m_body->sizeHint().height());
}

void ShellPopup::hideEvent(QHideEvent *e)
{
    QWidget::hideEvent(e);
    if (m_manageAsTopLevel)
        PopupManager::closed(this);
    g_grabStack.removeAll(this);
    /* Hand the keyboard grab back to the popup below us (submenu case). */
    for (int i = g_grabStack.size() - 1; i >= 0; i--) {
        ShellPopup *p = g_grabStack[i];
        if (p && p->isVisible()) {
            X11Util::grabKeyboard(p->winId());
            emit popupVisibleChanged(false);
            return;
        }
    }
    X11Util::ungrabKeyboard();
    emit popupVisibleChanged(false);
}
