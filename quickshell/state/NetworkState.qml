import QtQuick
import Quickshell
import Quickshell.Io

// Network state via the backend-adaptive dwm-qs-net bridge.
//   backend == "nm" -> NetworkManager: Wi-Fi list/connect/scan/radio.
//   backend == "ip" -> custom bridge/VLAN desktop: link status + re-apply.
Scope {
    id: root

    property string backend: "ip"
    property string device: ""
    property string gateway: ""

    // NetworkManager fields
    property bool wifiEnabled: false
    property string connectivity: ""
    property string kind: "none"        // wifi | ethernet | vpn | none
    property string connName: ""
    property string ssid: ""
    property int wifiSignal: 0
    property string security: ""
    property string ip4: ""

    // iproute2 (desktop) fields
    property var links: []              // [{name,state,type,addr}]

    // Wi-Fi scan results
    property var wifiNetworks: []       // [{ssid,signal,security,active}]
    property bool scanning: false

    readonly property bool online: connectivity === "full" || (backend === "ip" && gateway.length > 0)

    function parseStatus(block) {
        const lines = block.trim().split("\n");
        let lks = [];
        for (const line of lines) {
            if (line.indexOf("link\t") === 0) {
                const p = line.split("\t"); // link,name,state,type,addr
                lks.push({ name: p[1], state: p[2], type: p[3], addr: p[4] || "" });
                continue;
            }
            const i = line.indexOf("=");
            if (i < 0) continue;
            const k = line.slice(0, i), v = line.slice(i + 1);
            switch (k) {
            case "backend": root.backend = v; break;
            case "device": root.device = v; break;
            case "gateway": root.gateway = v; break;
            case "wifi_enabled": root.wifiEnabled = (v === "enabled"); break;
            case "connectivity": root.connectivity = v; break;
            case "kind": root.kind = v || "none"; break;
            case "name": root.connName = v; break;
            case "ssid": root.ssid = v; break;
            case "signal": root.wifiSignal = parseInt(v, 10) || 0; break;
            case "security": root.security = v; break;
            case "ip": root.ip4 = v; break;
            }
        }
        if (root.backend === "ip") root.links = lks;
    }

    function parseWifi(text) {
        let nets = [];
        const lines = text.trim().split("\n");
        for (const l of lines) {
            if (!l) continue;
            const p = l.split("\t"); // ssid, signal, security, active
            nets.push({ ssid: p[0], signal: parseInt(p[1], 10) || 0,
                        security: p[2] || "", active: p[3] === "1" });
        }
        root.wifiNetworks = nets;
        root.scanning = false;
    }

    function action(args) {
        actionProc.command = ["dwm-qs-net"].concat(args);
        actionProc.running = true;
    }
    function refreshWifi() { wifiListProc.running = true; }
    function wifiScan() { root.scanning = true; scanProc.running = true; }
    function wifiConnect(ssid, pw) {
        action(pw && pw.length ? ["wifi-connect", ssid, pw] : ["wifi-connect", ssid]);
    }
    function wifiDisconnect() { action(["wifi-disconnect"]); }
    function wifiForget(ssid) { action(["wifi-forget", ssid]); }
    function setRadio(on) { action(["radio", on ? "on" : "off"]); }
    function reapply() { action(["reapply"]); }
    function linkUp(n) { action(["link-up", n]); }
    function linkDown(n) { action(["link-down", n]); }

    Process {
        id: watchProc
        command: ["dwm-qs-net", "watch"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: function (data) { root.parseStatus(data); }
        }
    }
    Process {
        id: wifiListProc
        command: ["dwm-qs-net", "wifi-list"]
        stdout: StdioCollector { id: wc; onStreamFinished: root.parseWifi(wc.text) }
    }
    Process {
        id: scanProc
        command: ["dwm-qs-net", "wifi-scan"]
        onExited: root.refreshWifi()
    }
    Process {
        id: actionProc
        running: false
        onExited: root.refreshWifi()
    }

    // The watch is event-driven (nmcli monitor); poll status so the pill shows
    // the connection at startup and reflects signal changes without a click.
    Process {
        id: statusProc
        command: ["dwm-qs-net", "status"]
        stdout: StdioCollector { id: statusColl; onStreamFinished: root.parseStatus(statusColl.text) }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }
}
