pragma Singleton

import Quickshell
import Quickshell.Io

// Bluetooth state via the dwm-qs-bt bridge (bluetoothctl). Streams status
// blocks; exposes powered/discovering/devices and action methods.
// Singleton: exactly one watch process, no matter how many bars use it.
Singleton {
    id: root
    property bool powered: false
    property bool discovering: false
    property var devices: []
    readonly property int connectedCount: {
        let n = 0;
        for (const d of devices) if (d.connected) n++;
        return n;
    }

    function parse(block) {
        const lines = block.trim().split("\n");
        let devs = [];
        for (const line of lines) {
            if (line.indexOf("device\t") === 0) {
                const p = line.split("\t"); // device, mac, name, conn, paired
                devs.push({ mac: p[1], name: p[2], connected: p[3] === "1", paired: p[4] === "1" });
            } else {
                const i = line.indexOf("=");
                if (i < 0) continue;
                const k = line.slice(0, i), v = line.slice(i + 1);
                if (k === "powered") root.powered = (v === "yes");
                else if (k === "discovering") root.discovering = (v === "yes");
            }
        }
        root.devices = devs;
    }

    function action(args) {
        actionProc.command = ["dwm-qs-bt"].concat(args);
        actionProc.running = true;
    }
    function togglePower() { action(["power", powered ? "off" : "on"]); }
    function scan() { action(["scan", "8"]); }
    function connect(mac) { action(["connect", mac]); }
    function disconnect(mac) { action(["disconnect", mac]); }

    Process {
        id: watchProc
        command: ["dwm-qs-bt", "watch", "3"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: function (data) { root.parse(data); }
        }
    }
    Process {
        id: actionProc
        running: false
    }
}
