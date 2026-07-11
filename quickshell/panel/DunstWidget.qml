import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Dunst do-not-disturb toggle. Click pauses/unpauses notifications; the icon
// is a bell (active, blue) or crossed bell + waiting count (paused, red).
BarPill {
    id: root
    readonly property bool paused: DunstService.paused
    readonly property int waiting: DunstService.count

    icon: paused ? "" : ""
    label: (paused && waiting > 0) ? ("" + waiting) : ""
    tint: paused ? Theme.red : Theme.blue
    active: paused

    onClicked: DunstService.toggle()
    onRightClicked: DunstService.refresh()
}
