import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.core

// Bar pill for audio. Scroll = adjust output, right-click = mute, click = popup.
// Uses native PipeWire (no script). PwObjectTracker keeps the default sink and
// source bound so their .audio volume/mute are readable/writable.
BarPill {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int pct: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property int micPct: Math.round((source?.audio?.volume ?? 0) * 100)

    icon: muted ? "󰝟" : (pct > 66 ? "" : (pct > 33 ? "" : ""))
    // Output and mic are coloured independently by their own mute state: blue
    // when unmuted, purple when muted. On hover the pill highlight wins for both.
    readonly property string outColor: highlighted ? Theme.tagActive : (muted ? Theme.magenta : Theme.blue)
    readonly property string micColor: highlighted ? Theme.tagActive : (micMuted ? Theme.magenta : Theme.blue)

    // Output first (speaker glyph is the `icon`), then the mic inline. Each part
    // is wrapped in its own colour span so the mic tracks its own mute state.
    richLabel: true
    label: "<font color=\"" + outColor + "\">" + (muted ? "muted" : pct + "%") + "</font> "
           + "<font color=\"" + micColor + "\">" + (micMuted ? "\uf131" : "\uf130") + " " + (micMuted ? "muted" : micPct + "%") + "</font>"
    tint: muted ? Theme.magenta : Theme.blue
    active: popup.visible

    onClicked: popup.visible = !popup.visible
    onRightClicked: if (sink?.audio) sink.audio.muted = !sink.audio.muted
    onScrolled: function (d) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + d * 0.05));
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    VolumePopup {
        id: popup
        anchorItem: root
        sink: root.sink
        source: root.source
    }
}
