/* core/AppLauncher.qml: centered, IPC-triggered launcher with two modes:
 *   "apps" — .desktop entries;  "run" — executables on $PATH.
 * A fullscreen, WM-managed window titled "fandwm-launcher"; dwm recognizes it
 * (launchertitle in config.def.h) and manages it as a borderless fullscreen
 * floating overlay. Clicking outside the box dismisses it. */
#ifndef DWMQS_LAUNCHER_H
#define DWMQS_LAUNCHER_H

#include <QLineEdit>
#include <QScreen>
#include <QWidget>

#include "desktopentry.h"
#include "procutil.h"
#include "widgets.h"

struct LauncherItem {
    QString name;
    QString sub;
    QString icon;
    int appIndex = -1; /* index into DesktopEntries (apps mode) */
    QString cmd;       /* binary name (run mode) */
};

class LauncherWindow;

class AppLauncher : public QObject {
    Q_OBJECT
public:
    explicit AppLauncher(QObject *parent = nullptr);

    QString mode = QStringLiteral("apps"); /* "apps" | "run" */
    QStringList binaries;
    QVector<LauncherItem> entries;
    int selected = 0;
    static constexpr int columns = 2;
    QString searchText;

    void refilter();
    void launchSelected();
    void move(int delta);
    void openMode(const QString &m);
    void toggleMode(const QString &m);
    void hideLauncher();

    QScreen *pickScreen() const;

signals:
    void entriesChanged();
    void selectedChanged();

private:
    void scanBinaries();

    LauncherWindow *m_win;
    CollectorProcess m_binScan;
};

/* The results grid: 2 columns, 48px cells, GridView-style clipping/scroll. */
class LauncherGrid : public QWidget {
    Q_OBJECT
public:
    explicit LauncherGrid(AppLauncher *l, QWidget *parent = nullptr);

    int contentHeight() const;
    void ensureVisible();

protected:
    void paintEvent(QPaintEvent *) override;
    void mouseMoveEvent(QMouseEvent *) override;
    void mousePressEvent(QMouseEvent *) override;
    void wheelEvent(QWheelEvent *) override;
    void resizeEvent(QResizeEvent *) override;

private:
    int cellWidth() const { return width() / AppLauncher::columns; }
    int indexAt(const QPoint &p) const;
    void clampScroll();

    AppLauncher *m_l;
    int m_scroll = 0;
};

class LauncherWindow : public QWidget {
    Q_OBJECT
public:
    LauncherWindow(AppLauncher *l);

    void openOn(QScreen *screen);
    QLineEdit *search() const { return m_search; }

protected:
    void mousePressEvent(QMouseEvent *) override;
    void resizeEvent(QResizeEvent *) override;
    void showEvent(QShowEvent *) override;
    bool eventFilter(QObject *o, QEvent *e) override;
    void paintEvent(QPaintEvent *) override;

private:
    void layoutBox();

    AppLauncher *m_l;
    QWidget *m_box;
    QWidget *m_searchBar;
    QLineEdit *m_search;
    TextItem *m_placeholder;
    LauncherGrid *m_grid;
};

#endif
