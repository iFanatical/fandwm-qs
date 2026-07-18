/* core/Popup.qml + ShellSurface.qml + PopupManager.qml equivalents.
 *
 * A ShellPopup is an override-redirect (WM-bypassing) top-level with a
 * rounded, bordered surface and Theme.popupMargin padding. It grabs the
 * keyboard while shown (quickshell PopupWindow grabFocus) and closes on
 * Escape. There is intentionally no click-outside dismiss on X11; popups are
 * dismissed by click-to-toggle, Escape, or another popup opening. */
#ifndef DWMQS_POPUP_H
#define DWMQS_POPUP_H

#include <QPointer>
#include <QWidget>

class ShellPopup : public QWidget {
    Q_OBJECT
public:
    explicit ShellPopup(QWidget *anchor, int popupWidth);

    /* Popup top-left = anchor->mapToGlobal(rel). Default: under the anchor,
     * left-aligned, 4px gap (Popup.qml anchor.rect). */
    void setAnchorOffset(const QPoint &rel);
    void setPopupWidth(int w);

    virtual void openPopup();
    void closePopup();
    void togglePopup();

    /* Recompute size (content height changed) and reposition when visible. */
    void relayout();

signals:
    void popupVisibleChanged(bool visible);

protected:
    /* Height of the popup; default = layout()->sizeHint().height(). */
    virtual int popupHeight() const;

    void paintEvent(QPaintEvent *) override;
    void keyPressEvent(QKeyEvent *) override;
    void showEvent(QShowEvent *) override;
    void hideEvent(QHideEvent *) override;

    QPointer<QWidget> m_anchor;
    int m_width;
    QPoint m_rel;
    bool m_hasRel = false;
    /* false for submenus: they must not close their parent via
     * PopupManager (TrayMenu.qml topLevel). */
    bool m_manageAsTopLevel = true;
    quintptr m_prevFocus = 0;
};

/* A popup whose height follows its content column (Popup.qml pattern:
 * `popupHeight: col.implicitHeight + 2 * Theme.popupMargin`), optionally
 * clamped to a max height (content clips, no scrolling — QML parity). */
class ContentPopup : public ShellPopup {
    Q_OBJECT
public:
    ContentPopup(QWidget *anchor, int popupWidth, int maxHeight = 0);

    QWidget *body() const { return m_body; }
    class QVBoxLayout *bodyLayout() const { return m_bodyLayout; }

protected:
    int popupHeight() const override;
    void resizeEvent(QResizeEvent *) override;

private:
    QWidget *m_body;
    class QVBoxLayout *m_bodyLayout;
    int m_maxHeight;
};

namespace PopupManager {
/* Tracks the currently-open top-level popup so opening a new one closes the
 * previous. */
void opened(ShellPopup *p);
void closed(ShellPopup *p);
/* Close whatever popup is open (and release its keyboard grab) — used when
 * the launcher opens so a lingering grab can't swallow its keystrokes. */
void closeCurrent();
} /* namespace PopupManager */

#endif
