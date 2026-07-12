#include "volume.h"

#include <QHBoxLayout>
#include <QMouseEvent>
#include <QPainter>
#include <QVBoxLayout>

#include <pulse/pulseaudio.h>

static QString glyph(char32_t c)
{
    return QString::fromUcs4(&c, 1);
}

/* ------------------------------------------------------------ PulseBackend */

struct PulseBackend::Priv {
    pa_threaded_mainloop *loop = nullptr;
    pa_context *ctx = nullptr;
    QString defaultSinkName;
    QString defaultSourceName;
    uint8_t sinkChannels = 2;
    uint8_t sourceChannels = 1;

    /* Pending state assembled on the PA thread, then applied on the GUI
     * thread via queued invocation. */
};

struct PulseCallbacks {
    static void contextState(pa_context *c, void *ud)
    {
        auto *self = static_cast<PulseBackend *>(ud);
        if (pa_context_get_state(c) == PA_CONTEXT_READY) {
            pa_context_set_subscribe_callback(c, subscribe, ud);
            pa_operation *o = pa_context_subscribe(
                c,
                (pa_subscription_mask_t)(PA_SUBSCRIPTION_MASK_SINK
                                         | PA_SUBSCRIPTION_MASK_SOURCE
                                         | PA_SUBSCRIPTION_MASK_SERVER),
                nullptr, nullptr);
            if (o)
                pa_operation_unref(o);
            queryAll(self);
        }
    }

    static void subscribe(pa_context *, pa_subscription_event_type_t, uint32_t,
                          void *ud)
    {
        queryAll(static_cast<PulseBackend *>(ud));
    }

    static void queryAll(PulseBackend *self)
    {
        pa_operation *o =
            pa_context_get_server_info(self->d->ctx, serverInfo, self);
        if (o)
            pa_operation_unref(o);
    }

    static void serverInfo(pa_context *c, const pa_server_info *i, void *ud)
    {
        auto *self = static_cast<PulseBackend *>(ud);
        self->d->defaultSinkName =
            QString::fromUtf8(i->default_sink_name ? i->default_sink_name : "");
        self->d->defaultSourceName = QString::fromUtf8(
            i->default_source_name ? i->default_source_name : "");
        pa_operation *o;
        if (!self->d->defaultSinkName.isEmpty()) {
            o = pa_context_get_sink_info_by_name(
                c, self->d->defaultSinkName.toUtf8().constData(), sinkInfo,
                ud);
            if (o)
                pa_operation_unref(o);
        }
        if (!self->d->defaultSourceName.isEmpty()) {
            o = pa_context_get_source_info_by_name(
                c, self->d->defaultSourceName.toUtf8().constData(),
                sourceInfo, ud);
            if (o)
                pa_operation_unref(o);
        }
        o = pa_context_get_sink_info_list(c, sinkList, ud);
        if (o)
            pa_operation_unref(o);
    }

    static void sinkInfo(pa_context *, const pa_sink_info *i, int eol,
                         void *ud)
    {
        if (eol || !i)
            return;
        auto *self = static_cast<PulseBackend *>(ud);
        self->d->sinkChannels = i->volume.channels;
        const qreal vol =
            (qreal)pa_cvolume_avg(&i->volume) / (qreal)PA_VOLUME_NORM;
        const bool muted = i->mute != 0;
        QMetaObject::invokeMethod(
            self,
            [self, vol, muted]() {
                self->hasSink = true;
                self->sinkVolume = vol;
                self->sinkMuted = muted;
                emit self->changed();
            },
            Qt::QueuedConnection);
    }

    static void sourceInfo(pa_context *, const pa_source_info *i, int eol,
                           void *ud)
    {
        if (eol || !i)
            return;
        auto *self = static_cast<PulseBackend *>(ud);
        self->d->sourceChannels = i->volume.channels;
        const qreal vol =
            (qreal)pa_cvolume_avg(&i->volume) / (qreal)PA_VOLUME_NORM;
        const bool muted = i->mute != 0;
        QMetaObject::invokeMethod(
            self,
            [self, vol, muted]() {
                self->hasSource = true;
                self->sourceVolume = vol;
                self->sourceMuted = muted;
                emit self->changed();
            },
            Qt::QueuedConnection);
    }

    static void sinkList(pa_context *, const pa_sink_info *i, int eol,
                         void *ud)
    {
        auto *self = static_cast<PulseBackend *>(ud);
        static thread_local QVector<PulseBackend::Sink> pending;
        if (eol) {
            const QVector<PulseBackend::Sink> list = pending;
            pending.clear();
            const QString def = self->d->defaultSinkName;
            QMetaObject::invokeMethod(
                self,
                [self, list, def]() {
                    QVector<PulseBackend::Sink> l = list;
                    for (PulseBackend::Sink &s : l)
                        s.isDefault = (s.name == def);
                    self->sinks = l;
                    emit self->changed();
                },
                Qt::QueuedConnection);
            return;
        }
        if (!i)
            return;
        PulseBackend::Sink s;
        s.name = QString::fromUtf8(i->name ? i->name : "");
        s.description =
            QString::fromUtf8(i->description ? i->description : "");
        pending.push_back(s);
    }
};

PulseBackend *PulseBackend::instance()
{
    static PulseBackend *s = new PulseBackend();
    return s;
}

PulseBackend::PulseBackend(QObject *parent) : QObject(parent), d(new Priv)
{
    start();
}

void PulseBackend::start()
{
    d->loop = pa_threaded_mainloop_new();
    pa_mainloop_api *api = pa_threaded_mainloop_get_api(d->loop);
    d->ctx = pa_context_new(api, "dwm-qs-shell");
    pa_context_set_state_callback(d->ctx, PulseCallbacks::contextState, this);
    pa_context_connect(d->ctx, nullptr, PA_CONTEXT_NOFAIL, nullptr);
    pa_threaded_mainloop_start(d->loop);
}

void PulseBackend::setSinkVolume(qreal v)
{
    v = qMax<qreal>(0, qMin<qreal>(1, v));
    if (!hasSink || d->defaultSinkName.isEmpty())
        return;
    pa_threaded_mainloop_lock(d->loop);
    pa_cvolume cv;
    pa_cvolume_set(&cv, d->sinkChannels,
                   (pa_volume_t)qRound64(v * PA_VOLUME_NORM));
    pa_operation *o = pa_context_set_sink_volume_by_name(
        d->ctx, d->defaultSinkName.toUtf8().constData(), &cv, nullptr,
        nullptr);
    if (o)
        pa_operation_unref(o);
    pa_threaded_mainloop_unlock(d->loop);
    sinkVolume = v;
    emit changed();
}

void PulseBackend::setSinkMuted(bool m)
{
    if (!hasSink || d->defaultSinkName.isEmpty())
        return;
    pa_threaded_mainloop_lock(d->loop);
    pa_operation *o = pa_context_set_sink_mute_by_name(
        d->ctx, d->defaultSinkName.toUtf8().constData(), m ? 1 : 0, nullptr,
        nullptr);
    if (o)
        pa_operation_unref(o);
    pa_threaded_mainloop_unlock(d->loop);
    sinkMuted = m;
    emit changed();
}

void PulseBackend::setSourceVolume(qreal v)
{
    v = qMax<qreal>(0, qMin<qreal>(1, v));
    if (!hasSource || d->defaultSourceName.isEmpty())
        return;
    pa_threaded_mainloop_lock(d->loop);
    pa_cvolume cv;
    pa_cvolume_set(&cv, d->sourceChannels,
                   (pa_volume_t)qRound64(v * PA_VOLUME_NORM));
    pa_operation *o = pa_context_set_source_volume_by_name(
        d->ctx, d->defaultSourceName.toUtf8().constData(), &cv, nullptr,
        nullptr);
    if (o)
        pa_operation_unref(o);
    pa_threaded_mainloop_unlock(d->loop);
    sourceVolume = v;
    emit changed();
}

void PulseBackend::setSourceMuted(bool m)
{
    if (!hasSource || d->defaultSourceName.isEmpty())
        return;
    pa_threaded_mainloop_lock(d->loop);
    pa_operation *o = pa_context_set_source_mute_by_name(
        d->ctx, d->defaultSourceName.toUtf8().constData(), m ? 1 : 0, nullptr,
        nullptr);
    if (o)
        pa_operation_unref(o);
    pa_threaded_mainloop_unlock(d->loop);
    sourceMuted = m;
    emit changed();
}

void PulseBackend::setDefaultSink(const QString &name)
{
    pa_threaded_mainloop_lock(d->loop);
    pa_operation *o = pa_context_set_default_sink(
        d->ctx, name.toUtf8().constData(), nullptr, nullptr);
    if (o)
        pa_operation_unref(o);
    pa_threaded_mainloop_unlock(d->loop);
}

/* ----------------------------------------------------------- ClickableText */

ClickableText::ClickableText(QWidget *parent) : TextItem(parent)
{
    setCursor(Qt::PointingHandCursor);
}

void ClickableText::mousePressEvent(QMouseEvent *e)
{
    if (e->button() == Qt::LeftButton)
        m_pressed = true;
}

void ClickableText::mouseReleaseEvent(QMouseEvent *e)
{
    if (m_pressed && e->button() == Qt::LeftButton
            && rect().contains(e->pos()))
        emit clicked();
    m_pressed = false;
}

/* ------------------------------------------------------------ VolumeWidget */

VolumeWidget::VolumeWidget(QWidget *parent) : BarPill(parent)
{
    m_popup = new VolumePopup(this);
    connect(this, &BarPill::clicked, m_popup, &ShellPopup::togglePopup);
    connect(m_popup, &ShellPopup::popupVisibleChanged, this,
            &BarPill::setActive);
    connect(this, &BarPill::rightClicked, this, []() {
        PulseBackend *pa = PulseBackend::instance();
        if (pa->hasSink)
            pa->toggleSinkMuted();
    });
    connect(this, &BarPill::scrolled, this, [](int d) {
        PulseBackend *pa = PulseBackend::instance();
        if (pa->hasSink)
            pa->setSinkVolume(pa->sinkVolume + d * 0.05);
    });
    connect(this, &BarPill::hoverChanged, this, &VolumeWidget::sync);
    connect(PulseBackend::instance(), &PulseBackend::changed, this,
            &VolumeWidget::sync);
    sync();
}

void VolumeWidget::sync()
{
    PulseBackend *pa = PulseBackend::instance();
    const bool muted = pa->hasSink && pa->sinkMuted;
    const int pct = qRound(pa->sinkVolume * 100);
    const bool micMuted = pa->hasSource && pa->sourceMuted;
    const int micPct = qRound(pa->sourceVolume * 100);

    setIcon(muted ? glyph(U'\U000F075F')
                  : (pct > 66 ? glyph(U'\uf028')
                              : (pct > 33 ? glyph(U'\uf027') : glyph(U'\uf026'))));
    setTint(muted ? Theme::magenta : Theme::blue);

    /* Output and mic coloured independently by their own mute state: blue
     * when unmuted, purple when muted. On hover the pill highlight wins. */
    const QColor outColor =
        highlighted() ? Theme::tagActive
                      : (muted ? Theme::magenta : Theme::blue);
    const QColor micColor =
        highlighted() ? Theme::tagActive
                      : (micMuted ? Theme::magenta : Theme::blue);
    QVector<Segment> segs;
    segs.push_back({muted ? QStringLiteral("muted")
                          : QString::number(pct) + QStringLiteral("%"),
                    outColor});
    segs.push_back({QStringLiteral(" "), QColor()});
    segs.push_back({(micMuted ? glyph(U'\uf131') : glyph(U'\uf130'))
                        + QStringLiteral(" ")
                        + (micMuted ? QStringLiteral("muted")
                                    : QString::number(micPct)
                                          + QStringLiteral("%")),
                    micColor});
    setRichSegments(segs);
}

/* -------------------------------------------------------------- device row */

namespace {

class SinkRow : public QWidget {
public:
    SinkRow(const PulseBackend::Sink &s, QWidget *parent)
        : QWidget(parent), m_s(s)
    {
        setMouseTracking(true);
        setCursor(Qt::PointingHandCursor);
        setFixedHeight(24);
        setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
    }

protected:
    void paintEvent(QPaintEvent *) override
    {
        QPainter p(this);
        Theme::paintRect(p, rect(),
                         m_hover ? Theme::surfaceHover
                                 : (m_s.isDefault ? Theme::surface
                                                  : Theme::transparent),
                         Theme::smallRadius);
        p.setFont(Theme::font(Theme::smallFontSize));
        p.setPen(m_s.isDefault ? Theme::accent : Theme::text);
        const QString label = (m_s.isDefault ? QStringLiteral(" ")
                                             : QString())
                              + m_s.description;
        const QFontMetrics fm(p.font());
        p.drawText(QRect(8, 0, width() - 16, height()),
                   Qt::AlignLeft | Qt::AlignVCenter,
                   fm.elidedText(label, Qt::ElideRight, width() - 16));
    }

    void enterEvent(QEnterEvent *) override { m_hover = true; update(); }
    void leaveEvent(QEvent *) override { m_hover = false; update(); }
    void mousePressEvent(QMouseEvent *e) override
    {
        if (e->button() == Qt::LeftButton)
            m_pressed = true;
    }
    void mouseReleaseEvent(QMouseEvent *e) override
    {
        if (m_pressed && e->button() == Qt::LeftButton
                && rect().contains(e->pos()))
            PulseBackend::instance()->setDefaultSink(m_s.name);
        m_pressed = false;
    }

private:
    PulseBackend::Sink m_s;
    bool m_hover = false;
    bool m_pressed = false;
};

TextItem *sectionLabel(const QString &text, QWidget *parent)
{
    auto *t = new TextItem(parent);
    t->setPixelSize(Theme::smallFontSize);
    t->setBold(true);
    t->setColor(Theme::textMuted);
    t->setText(text);
    return t;
}

} /* namespace */

/* ------------------------------------------------------------- VolumePopup */

VolumePopup::VolumePopup(QWidget *anchor) : ContentPopup(anchor, 320)
{
    auto *lay = bodyLayout();
    PulseBackend *pa = PulseBackend::instance();

    /* ---- Output ---- */
    lay->addWidget(sectionLabel(QStringLiteral("Output"), body()));
    auto *outRow = new QWidget(body());
    auto *ol = new QHBoxLayout(outRow);
    ol->setContentsMargins(0, 0, 0, 0);
    ol->setSpacing(Theme::rowSpacing);
    m_outIcon = new ClickableText(outRow);
    m_outIcon->setPixelSize(Theme::bodyFontSize);
    m_outIcon->setFixedWidth(20);
    m_outSlider = new ValueSlider(outRow);
    m_outSlider->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
    m_outPct = new TextItem(outRow);
    m_outPct->setPixelSize(Theme::smallFontSize);
    m_outPct->setHAlign(Qt::AlignRight);
    m_outPct->setFixedWidth(44);
    ol->addWidget(m_outIcon, 0, Qt::AlignVCenter);
    ol->addWidget(m_outSlider, 1, Qt::AlignVCenter);
    ol->addWidget(m_outPct, 0, Qt::AlignVCenter);
    lay->addWidget(outRow);

    connect(m_outIcon, &ClickableText::clicked, this, [pa]() {
        if (pa->hasSink)
            pa->toggleSinkMuted();
    });
    connect(m_outSlider, &ValueSlider::moved, this, [pa](qreal v) {
        if (pa->hasSink)
            pa->setSinkVolume(v);
    });

    /* ---- Input (mic) ---- */
    lay->addWidget(sectionLabel(QStringLiteral("Input"), body()));
    auto *micRow = new QWidget(body());
    auto *ml = new QHBoxLayout(micRow);
    ml->setContentsMargins(0, 0, 0, 0);
    ml->setSpacing(Theme::rowSpacing);
    m_micIcon = new ClickableText(micRow);
    m_micIcon->setPixelSize(Theme::bodyFontSize);
    m_micIcon->setFixedWidth(20);
    m_micSlider = new ValueSlider(micRow);
    m_micSlider->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
    m_micPct = new TextItem(micRow);
    m_micPct->setPixelSize(Theme::smallFontSize);
    m_micPct->setHAlign(Qt::AlignRight);
    m_micPct->setFixedWidth(44);
    ml->addWidget(m_micIcon, 0, Qt::AlignVCenter);
    ml->addWidget(m_micSlider, 1, Qt::AlignVCenter);
    ml->addWidget(m_micPct, 0, Qt::AlignVCenter);
    lay->addWidget(micRow);

    connect(m_micIcon, &ClickableText::clicked, this, [pa]() {
        if (pa->hasSource)
            pa->toggleSourceMuted();
    });
    connect(m_micSlider, &ValueSlider::moved, this, [pa](qreal v) {
        if (pa->hasSource)
            pa->setSourceVolume(v);
    });

    lay->addWidget(new HLine(body()));
    lay->addWidget(sectionLabel(QStringLiteral("Output device"), body()));

    m_deviceBox = new QWidget(body());
    auto *dl = new QVBoxLayout(m_deviceBox);
    dl->setContentsMargins(0, 0, 0, 0);
    dl->setSpacing(Theme::popupSpacing);
    lay->addWidget(m_deviceBox);
    lay->addStretch(0);

    connect(pa, &PulseBackend::changed, this, &VolumePopup::sync);
    sync();
}

void VolumePopup::sync()
{
    PulseBackend *pa = PulseBackend::instance();

    m_outIcon->setText(pa->sinkMuted ? glyph(U'\U000F075F') : glyph(U'\uf028'));
    m_outIcon->setColor(pa->sinkMuted ? Theme::selected : Theme::accent);
    m_outSlider->setValue(pa->sinkVolume);
    m_outSlider->setFillColor(pa->sinkMuted ? Theme::textMuted
                                            : Theme::accent);
    m_outPct->setText(QString::number(qRound(pa->sinkVolume * 100))
                      + QStringLiteral("%"));

    m_micIcon->setText(pa->sourceMuted ? glyph(U'\uf131') : glyph(U'\uf130'));
    m_micIcon->setColor(pa->sourceMuted ? Theme::selected : Theme::accent);
    m_micSlider->setValue(pa->sourceVolume);
    m_micSlider->setFillColor(pa->sourceMuted ? Theme::textMuted
                                              : Theme::success);
    m_micPct->setText(QString::number(qRound(pa->sourceVolume * 100))
                      + QStringLiteral("%"));

    rebuildDevices();
}

void VolumePopup::rebuildDevices()
{
    PulseBackend *pa = PulseBackend::instance();
    QStringList key;
    for (const PulseBackend::Sink &s : pa->sinks)
        key << s.name + (s.isDefault ? QStringLiteral("*") : QString());
    if (key == m_deviceKey)
        return;
    m_deviceKey = key;

    auto *dl = static_cast<QVBoxLayout *>(m_deviceBox->layout());
    while (QLayoutItem *it = dl->takeAt(0)) {
        if (it->widget())
            it->widget()->deleteLater();
        delete it;
    }
    for (const PulseBackend::Sink &s : pa->sinks) {
        auto *row = new SinkRow(s, m_deviceBox);
        dl->addWidget(row);
        row->show();
    }
    if (isVisible())
        relayout();
}
