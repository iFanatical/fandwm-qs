import QtQuick
import Quickshell
import qs.core

Popup {
    id: root
    property var bt   // BluetoothState

    popupWidth: 320
    popupHeight: col.implicitHeight + 2 * Theme.popupMargin

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.popupSpacing

        Item {
            width: parent.width
            height: powerBtn.height
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                color: Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                font.bold: true
            }
            ShellButton {
                id: powerBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: (root.bt?.powered ?? false) ? "On" : "Off"
                active: root.bt?.powered ?? false
                onActivated: root.bt?.togglePower()
            }
            ShellButton {
                id: scanBtn
                anchors.right: powerBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                label: (root.bt?.discovering ?? false) ? "Scanning…" : "Scan"
                enabled: root.bt?.powered ?? false
                onActivated: root.bt?.scan()
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Text {
            visible: (root.bt?.devices?.length ?? 0) === 0
            text: root.bt?.powered ? "No devices — hit Scan." : "Bluetooth is off."
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }

        Repeater {
            model: root.bt?.devices ?? []
            delegate: Rectangle {
                required property var modelData
                width: col.width
                height: 34
                radius: Theme.smallRadius
                color: rowMouse.containsMouse ? Theme.surfaceHover : (modelData.connected ? Theme.surface : "transparent")

                Column {
                    anchors.left: parent.left
                    anchors.right: connectChip.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: modelData.name
                        color: Theme.text
                        elide: Text.ElideRight
                        width: parent.width
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                    }
                    Text {
                        text: (modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")) + " · " + modelData.mac
                        color: modelData.connected ? Theme.success : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.tinyFontSize
                    }
                }

                ShellButton {
                    id: connectChip
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    label: modelData.connected ? "Disconnect" : "Connect"
                    danger: modelData.connected
                    onActivated: modelData.connected ? root.bt.disconnect(modelData.mac) : root.bt.connect(modelData.mac)
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
