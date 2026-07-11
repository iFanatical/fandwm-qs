import QtQuick
import qs.core

Rectangle {
    id: root
    required property string label
    property bool danger: false
    property bool active: false
    signal activated()

    implicitWidth: buttonLabel.implicitWidth + 22
    implicitHeight: Theme.buttonHeight
    radius: Theme.radius
    color: mouse.containsMouse && enabled ? Theme.surfaceHover : Theme.surface
    border.color: root.danger ? Theme.danger : (root.active ? Theme.accent : Theme.border)
    border.width: 1
    opacity: enabled ? 1 : 0.5

    Text {
        id: buttonLabel
        anchors.centerIn: parent
        text: root.label
        color: root.danger ? Theme.danger : (root.active ? Theme.accent : Theme.text)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallFontSize
        font.bold: true
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
