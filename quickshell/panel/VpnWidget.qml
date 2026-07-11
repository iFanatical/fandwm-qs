import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// WireGuard tun1 indicator/toggle. Click = toggle, right-click = refresh.
// Polls dwm-qs-vpn every few seconds; refreshes immediately after a toggle.
BarPill {
    id: root
    property bool up: false
    property string vpnIp: ""

    icon: up ? "󰦝" : "󰦞"
    label: "VPN"
    tint: up ? Theme.success : Theme.red
    active: up

    onClicked: toggleProc.running = true
    onRightClicked: statusProc.running = true

    function parse(text) {
        const lines = text.trim().split("\n");
        for (const l of lines) {
            const i = l.indexOf("=");
            if (i < 0) continue;
            const k = l.slice(0, i), v = l.slice(i + 1);
            if (k === "state") root.up = (v === "up");
            else if (k === "ip") root.vpnIp = v;
        }
    }

    Process {
        id: statusProc
        command: ["dwm-qs-vpn", "status"]
        stdout: StdioCollector { id: sc; onStreamFinished: root.parse(sc.text) }
    }
    Process {
        id: toggleProc
        command: ["dwm-qs-vpn", "toggle"]
        stdout: StdioCollector { id: tc; onStreamFinished: root.parse(tc.text) }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }
}
