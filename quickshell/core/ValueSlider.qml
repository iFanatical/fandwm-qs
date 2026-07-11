import QtQuick
import qs.core

// Minimal 0..1 horizontal slider. Emits moved(value) during drag/click.
Item {
    id: root
    property real value: 0
    property color fillColor: Theme.accent
    signal moved(real v)

    implicitHeight: 16

    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.surface

        Rectangle {
            width: root.clamp(root.value) * parent.width
            height: parent.height
            radius: 3
            color: root.fillColor
        }
    }

    Rectangle {
        width: 12
        height: 12
        radius: 6
        color: root.fillColor
        border.color: Theme.bg
        border.width: 1
        anchors.verticalCenter: parent.verticalCenter
        x: root.clamp(root.value) * (root.width - width)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function apply(mx) { root.moved(root.clamp(mx / root.width)); }
        onPressed: function (mouse) { apply(mouse.x); }
        onPositionChanged: function (mouse) { if (pressed) apply(mouse.x); }
    }
}
