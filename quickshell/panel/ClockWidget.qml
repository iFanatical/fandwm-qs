import QtQuick
import qs.core

BarPill {
    id: root
    property var clock

    icon: "\uf073"
    label: clock ? Qt.formatDateTime(clock.date, "ddd, MMM dd HH:mm:ss") : ""
    tint: Theme.accent
    active: cal.visible

    onClicked: cal.visible = !cal.visible

    CalendarPopup {
        id: cal
        anchorItem: root
        clock: root.clock
    }
}
