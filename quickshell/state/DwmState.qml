import Quickshell
import Quickshell.Io

// Live dwm-qs window-manager state, sourced from the dwm-qs-state bridge.
Scope {
    id: root

    property int currentWorkspace: 0
    property int occupiedMask: 0
    property var workspaceNames: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    property string layout: ""
    property string statusText: ""
    property var statusSegments: []
    // Per-monitor records: [{num,x,y,w,h,selMask,occMask,sel,layout}]
    property var monitors: []

    function parseState(text) {
        const lines = text.trim().split("\n");
        let mons = [];
        for (const line of lines) {
            if (line.indexOf("monitor\t") === 0) {
                const f = line.slice(8).trim().split(/\s+/);
                if (f.length >= 9)
                    mons.push({
                        num: parseInt(f[0], 10) || 0,
                        x: parseInt(f[1], 10) || 0,
                        y: parseInt(f[2], 10) || 0,
                        w: parseInt(f[3], 10) || 0,
                        h: parseInt(f[4], 10) || 0,
                        selMask: parseInt(f[5], 10) || 0,
                        occMask: parseInt(f[6], 10) || 0,
                        sel: f[7] === "1",
                        // Layout is a single space-free token; the title is
                        // the remainder and may contain spaces.
                        layout: f[8] || "",
                        title: f.slice(9).join(" ")
                    });
                continue;
            }
            const sep = line.indexOf("=");
            if (sep < 0)
                continue;
            const key = line.slice(0, sep);
            const value = line.slice(sep + 1);
            if (key === "current") {
                const parsed = parseInt(value, 10);
                root.currentWorkspace = isNaN(parsed) ? 0 : parsed;
            } else if (key === "occupied") {
                const mask = parseInt(value, 10);
                root.occupiedMask = isNaN(mask) ? 0 : mask;
            } else if (key === "names") {
                root.workspaceNames = value.length > 0 ? value.split("|") : [];
            } else if (key === "layout") {
                root.layout = value;
            } else if (key === "status") {
                root.statusText = value;
                root.updateStatusSegments();
            }
        }
        if (mons.length > 0)
            root.monitors = mons;
    }

    function updateStatusSegments() {
        // Strip dwmblocks / statuscmd color markup (^c#rrggbb^, ^b^, ^d^,
        // ^f20^, ^r0,0,5,5^ ...) which QuickShell cannot render.
        const text = root.statusText.replace(/\^[^^]*\^/g, "").trim();
        if (text.length === 0 || text.indexOf("dwm-") === 0) {
            root.statusSegments = [];
            return;
        }
        root.statusSegments = text.split(/\s+\|\s+| {2,}/).filter(function (s) {
            return s.trim().length > 0;
        });
    }

    function switchWorkspace(mon, index) {
        switchProcess.command = ["dwm-qs-state", "switch", mon.toString(), index.toString()];
        switchProcess.running = true;
    }

    Process {
        command: ["dwm-qs-state", "watch"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: function (data) {
                root.parseState(data);
            }
        }
    }

    Process {
        id: switchProcess
        running: false
    }
}

