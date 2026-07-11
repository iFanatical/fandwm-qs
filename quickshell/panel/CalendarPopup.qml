import QtQuick
import Quickshell
import qs.core

// Themed month calendar. `today` tracks the SystemClock so it rolls over at
// midnight; ‹ › navigate months. No external calendar module needed.
Popup {
    id: root
    property var clock
    readonly property date today: clock ? clock.date : new Date()
    property int monthOffset: 0

    popupWidth: 260
    popupHeight: colc.implicitHeight + 2 * Theme.popupMargin

    onVisibleChanged: if (visible) monthOffset = 0

    function viewDate() {
        return new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
    }

    // Array of {day, cur, today} cells including leading/trailing blanks.
    property var days: {
        const vd = viewDate();
        const year = vd.getFullYear(), month = vd.getMonth();
        const first = new Date(year, month, 1).getDay(); // 0=Sun
        const dim = new Date(year, month + 1, 0).getDate();
        const t = today;
        let arr = [];
        for (let i = 0; i < first; i++) arr.push({ day: 0, cur: false, today: false });
        for (let d = 1; d <= dim; d++) {
            const isToday = monthOffset === 0 && d === t.getDate()
                          && month === t.getMonth() && year === t.getFullYear();
            arr.push({ day: d, cur: true, today: isToday });
        }
        while (arr.length % 7 !== 0) arr.push({ day: 0, cur: false, today: false });
        return arr;
    }

    Column {
        id: colc
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.popupSpacing

        // header: ‹  Month Year  ›
        Item {
            width: parent.width
            height: 24
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.monthOffset-- }
            }
            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(root.viewDate(), "MMMM yyyy")
                color: Theme.accent
                font.bold: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.monthOffset++ }
            }
        }

        Grid {
            id: grid
            columns: 7
            width: parent.width
            readonly property real cell: width / 7

            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: grid.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][index]
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.tinyFontSize
                    font.bold: true
                }
            }
            Repeater {
                model: root.days
                delegate: Item {
                    required property var modelData
                    width: grid.cell
                    height: grid.cell
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: 12
                        color: modelData.today ? Theme.accent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.day > 0 ? modelData.day : ""
                            color: modelData.today ? Theme.bg : (modelData.cur ? Theme.text : Theme.textMuted)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                            font.bold: modelData.today
                        }
                    }
                }
            }
        }
    }
}
