/* Minimal XDG .desktop database (the DesktopEntries side of AppLauncher.qml):
 * scans XDG data dirs, exposes visible applications, and launches them with
 * Exec field-code handling and Terminal=true support. */
#ifndef DWMQS_DESKTOPENTRY_H
#define DWMQS_DESKTOPENTRY_H

#include <QObject>
#include <QString>
#include <QVector>

class DesktopEntry {
public:
    QString id;          /* desktop file id, e.g. org.gnome.Calculator */
    QString name;
    QString genericName;
    QString comment;
    QString icon;
    QString exec;
    QString workingDir;  /* Path= */
    bool terminal = false;
    bool noDisplay = false;

    void execute() const;
};

class DesktopEntries : public QObject {
    Q_OBJECT
public:
    static DesktopEntries *instance();

    const QVector<DesktopEntry> &applications() const { return m_apps; }

signals:
    void valuesChanged();

private:
    explicit DesktopEntries(QObject *parent = nullptr);
    void scan();

    QVector<DesktopEntry> m_apps;
};

#endif
