pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dunst state, refreshed via IPC (no polling). Trigger from your dunst keybind:
//   qs ipc call dunst toggle     -> pause/unpause + refresh the widget
//   qs ipc call dunst refresh    -> just refresh (after an external change)
Scope {
    id: root
    property bool paused: false
    property int count: 0

    function refresh() { statusProc.running = true; }
    function toggle() { toggleProc.running = true; }

    function parse(text) {
        const lines = text.trim().split("\n");
        for (const l of lines) {
            const i = l.indexOf("=");
            if (i < 0) continue;
            const k = l.slice(0, i), v = l.slice(i + 1);
            if (k === "paused") root.paused = (v === "true");
            else if (k === "count") root.count = parseInt(v, 10) || 0;
        }
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: "dunst"
        function refresh(): void { root.refresh(); }
        function toggle(): void { root.toggle(); }
    }

    Process {
        id: statusProc
        command: ["dwm-qs-dunst", "status"]
        stdout: StdioCollector { id: sc; onStreamFinished: root.parse(sc.text) }
    }
    Process {
        id: toggleProc
        command: ["dwm-qs-dunst", "toggle"]
        stdout: StdioCollector { id: tc; onStreamFinished: root.parse(tc.text) }
    }
}
