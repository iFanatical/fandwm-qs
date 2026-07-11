import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// A read-only bar pill fed by a script that prints `icon=`, `text=`, and
// optional `color=` lines. Polled on `interval`. Hides when it prints nothing
// (e.g. the battery script exits empty on a desktop with no battery).
BarPill {
    id: root
    property var command: []
    property int interval: 3000
    property bool hideWhenEmpty: true

    property string _icon: ""
    property string _text: ""
    property string _color: ""

    icon: _icon
    label: _text
    tint: _color.length > 0 ? _color : Theme.text
    visible: !hideWhenEmpty || _text.length > 0 || _icon.length > 0

    function parse(out) {
        var ic = "", tx = "", cl = "";
        var lines = out.trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var s = lines[i].indexOf("=");
            if (s < 0) continue;
            var k = lines[i].slice(0, s), v = lines[i].slice(s + 1);
            if (k === "icon") ic = v;
            else if (k === "text") tx = v;
            else if (k === "color") cl = v;
        }
        _icon = ic; _text = tx; _color = cl;
    }

    Process {
        id: proc
        command: root.command
        stdout: StdioCollector { id: coll; onStreamFinished: root.parse(coll.text) }
    }
    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
