import QtQuick
import qs.core
import qs.state

BarPill {
    id: root
    // shared singleton — one watch process for all bars
    readonly property var netState: NetworkState
    readonly property var net: netState
    readonly property bool nm: netState.backend === "nm"

    icon: {
        if (nm) {
            if (netState.kind === "wifi") {
                const s = netState.wifiSignal;
                return s >= 75 ? "󰤨" : s >= 50 ? "󰤥" : s >= 25 ? "󰤢" : s > 0 ? "󰤟" : "󰤯";
            }
            if (netState.kind === "ethernet") return "󰈀";
            if (!netState.wifiEnabled) return "󰤭";
            return "󰤮";
        }
        return netState.online ? "󰈀" : "󰤮";
    }
    label: nm ? (netState.kind === "wifi" ? netState.ssid : "") : netState.device
    tint: netState.online ? Theme.brightgreen : Theme.textMuted
    active: popup.visible

    onClicked: popup.visible = !popup.visible
    onRightClicked: if (nm) netState.wifiScan()

    NetworkPopup {
        id: popup
        anchorItem: root
        net: netState
    }
}
