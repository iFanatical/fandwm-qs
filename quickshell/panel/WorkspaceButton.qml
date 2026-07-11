import QtQuick
import QtQuick.Layouts
import qs.core

Rectangle {
    id: root

    required property string label
    required property bool selected
    required property bool occupied
    signal clicked()

    Layout.preferredWidth: Theme.workspaceButtonSize
    Layout.preferredHeight: Theme.workspaceButtonSize
    radius: Theme.smallRadius
    color: selected ? Theme.surface : (mouse.containsMouse ? Theme.surfaceHover : "transparent")

    Text {
        anchors.centerIn: parent
        text: root.label
        // active = cyan, has windows = white, empty = gray
        color: root.selected ? Theme.tagActive
             : (root.occupied ? Theme.tagOccupied : Theme.tagEmpty)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelFontSize
        font.bold: root.selected || root.occupied
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
