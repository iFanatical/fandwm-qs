/* panel/VolumeWidget.qml + panel/VolumePopup.qml.
 *
 * The QML used Quickshell.Services.Pipewire natively; here the native,
 * event-driven backend is libpulse against pipewire-pulse (volumes read and
 * written on the same 0..1 scale wpctl/quickshell display). */
#ifndef DWMQS_VOLUME_H
#define DWMQS_VOLUME_H

#include <QVector>

#include "popup.h"
#include "widgets.h"

struct pa_threaded_mainloop;
struct pa_context;

class PulseBackend : public QObject {
    Q_OBJECT
public:
    struct Sink {
        QString name;
        QString description;
        bool isDefault = false;
    };

    static PulseBackend *instance();

    /* Default sink (output) / source (mic) state. */
    qreal sinkVolume = 0;   /* 0..1 */
    bool sinkMuted = false;
    bool hasSink = false;
    qreal sourceVolume = 0;
    bool sourceMuted = false;
    bool hasSource = false;
    QVector<Sink> sinks;

    void setSinkVolume(qreal v);
    void setSinkMuted(bool m);
    void toggleSinkMuted() { setSinkMuted(!sinkMuted); }
    void setSourceVolume(qreal v);
    void setSourceMuted(bool m);
    void toggleSourceMuted() { setSourceMuted(!sourceMuted); }
    void setDefaultSink(const QString &name);

signals:
    void changed();

private:
    explicit PulseBackend(QObject *parent = nullptr);
    void start();

    friend struct PulseCallbacks;
    struct Priv;
    Priv *d;
};

class VolumePopup;

class VolumeWidget : public BarPill {
    Q_OBJECT
public:
    explicit VolumeWidget(QWidget *parent = nullptr);

private:
    void sync();

    VolumePopup *m_popup;
};

class VolumePopup : public ContentPopup {
    Q_OBJECT
public:
    explicit VolumePopup(QWidget *anchor);

private:
    void sync();
    void rebuildDevices();

    class ClickableText *m_outIcon;
    ValueSlider *m_outSlider;
    TextItem *m_outPct;
    class ClickableText *m_micIcon;
    ValueSlider *m_micSlider;
    TextItem *m_micPct;
    QWidget *m_deviceBox;
    QStringList m_deviceKey; /* to avoid rebuilding rows needlessly */
};

/* A QML Text with a MouseArea: fixed-width clickable glyph. */
class ClickableText : public TextItem {
    Q_OBJECT
public:
    explicit ClickableText(QWidget *parent = nullptr);

signals:
    void clicked();

protected:
    void mousePressEvent(QMouseEvent *) override;
    void mouseReleaseEvent(QMouseEvent *) override;

private:
    bool m_pressed = false;
};

#endif
