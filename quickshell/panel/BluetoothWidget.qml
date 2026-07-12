import QtQuick
import qs.core
import qs.state

BarPill {
    id: root

    // shared singleton — one watch process for all bars
    readonly property var bt: BluetoothState

    icon: !bt.powered ? "󰂲" : (bt.connectedCount > 0 ? "󰂱" : "󰂯")
    tint: bt.connectedCount > 0 ? Theme.accent : (bt.powered ? Theme.text : Theme.textMuted)
    active: popup.visible

    onClicked: popup.visible = !popup.visible

    BluetoothPopup {
        id: popup
        anchorItem: root
        bt: bt
    }
}
