import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.core

// Output + input volume sliders, mute toggles, and output-device switching.
Popup {
    id: root
    property PwNode sink
    property PwNode source

    popupWidth: 320
    popupHeight: col.implicitHeight + 2 * Theme.popupMargin

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.popupSpacing

        // ---- Output ----
        Text {
            text: "Output"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            font.bold: true
        }
        Row {
            width: parent.width
            spacing: 8
            Text {
                width: 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.sink?.audio?.muted ? "󰝟" : ""
                color: root.sink?.audio?.muted ? Theme.selected : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
                }
            }
            ValueSlider {
                width: parent.width - 20 - 44 - 16
                anchors.verticalCenter: parent.verticalCenter
                value: root.sink?.audio?.volume ?? 0
                fillColor: root.sink?.audio?.muted ? Theme.textMuted : Theme.accent
                onMoved: function (v) { if (root.sink?.audio) root.sink.audio.volume = v; }
            }
            Text {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
        }

        // ---- Input (mic) ----
        Text {
            text: "Input"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            font.bold: true
        }
        Row {
            width: parent.width
            spacing: 8
            Text {
                width: 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.source?.audio?.muted ? "" : ""
                color: root.source?.audio?.muted ? Theme.selected : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
                }
            }
            ValueSlider {
                width: parent.width - 20 - 44 - 16
                anchors.verticalCenter: parent.verticalCenter
                value: root.source?.audio?.volume ?? 0
                fillColor: root.source?.audio?.muted ? Theme.textMuted : Theme.success
                onMoved: function (v) { if (root.source?.audio) root.source.audio.volume = v; }
            }
            Text {
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round((root.source?.audio?.volume ?? 0) * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Text {
            text: "Output device"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            font.bold: true
        }

        Repeater {
            model: Pipewire.nodes
            delegate: Rectangle {
                required property PwNode modelData
                readonly property bool isOutput: modelData.audio && modelData.isSink && !modelData.isStream
                readonly property bool current: modelData === Pipewire.defaultAudioSink
                visible: isOutput
                width: col.width
                height: isOutput ? 24 : 0
                radius: Theme.smallRadius
                color: devMouse.containsMouse ? Theme.surfaceHover : (current ? Theme.surface : "transparent")

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: (parent.current ? " " : "") + (modelData.description || modelData.nickname || modelData.name)
                    color: parent.current ? Theme.accent : Theme.text
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }
                MouseArea {
                    id: devMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }
    }
}
