import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Centered, IPC-triggered application launcher. Reads .desktop entries via
// DesktopEntries (so it handles Exec field codes / Terminal=true correctly)
// and themes itself from Theme.qml, matching the dwm-qs panel.
//
// Trigger from dwm with:
//   quickshell ipc call launcher toggle
// (also: show / hide). A full-screen focusable PanelWindow dims the desktop
// and grabs the keyboard; Escape or a click on the backdrop dismisses it.
Scope {
    id: root

    // Screen the launcher appears on; set from shell.qml (primary monitor).
    property var screen: null

    IpcHandler {
        target: "launcher"
        function toggle(): void { win.visible = !win.visible; }
        function show(): void { win.visible = true; }
        function hide(): void { win.visible = false; }
    }

    PanelWindow {
        id: win
        screen: root.screen
        visible: false
        focusable: true
        exclusionMode: ExclusionMode.Ignore
        color: "#cc1a1b26" // dimmed Tokyo Night bg backdrop

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Filtered, name-sorted list of visible desktop entries.
        property var entries: []
        property int selected: 0

        function refilter() {
            var q = search.text.toLowerCase().trim();
            var all = DesktopEntries.applications.values;
            var out = [];
            for (var i = 0; i < all.length; i++) {
                var e = all[i];
                if (e.noDisplay)
                    continue;
                if (q === ""
                        || (e.name && e.name.toLowerCase().indexOf(q) >= 0)
                        || (e.genericName && e.genericName.toLowerCase().indexOf(q) >= 0)
                        || (e.comment && e.comment.toLowerCase().indexOf(q) >= 0))
                    out.push(e);
            }
            out.sort(function (a, b) {
                return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase());
            });
            entries = out;
            selected = 0;
        }

        function launch() {
            if (selected >= 0 && selected < entries.length) {
                entries[selected].execute();
                visible = false;
            }
        }

        function move(delta) {
            if (entries.length === 0)
                return;
            selected = (selected + delta + entries.length) % entries.length;
            list.positionViewAtIndex(selected, ListView.Contain);
        }

        onVisibleChanged: {
            if (visible) {
                search.text = "";
                refilter();
                search.forceActiveFocus();
            }
        }

        // Click on the backdrop (outside the box) closes the launcher.
        MouseArea {
            anchors.fill: parent
            onClicked: win.visible = false
        }

        Rectangle {
            id: box
            width: 600
            height: Math.min(520, header.height + list.contentHeight + 2 * Theme.popupMargin)
            anchors.centerIn: parent
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            radius: Theme.radius

            // Swallow clicks so they don't fall through to the backdrop.
            MouseArea { anchors.fill: parent }

            Column {
                id: header
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: Theme.popupMargin
                }
                spacing: Theme.listSpacing

                Rectangle {
                    width: parent.width
                    height: Theme.buttonHeight
                    color: Theme.surface
                    radius: Theme.smallRadius

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.popupMargin
                        anchors.rightMargin: Theme.popupMargin
                        spacing: Theme.rowSpacing

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "" // nerd-font search glyph
                            color: Theme.cyan
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.bodyFontSize
                        }

                        TextInput {
                            id: search
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.bodyFontSize
                            clip: true
                            selectByMouse: true
                            selectionColor: Theme.cyan
                            focus: true

                            onTextChanged: win.refilter()

                            Keys.onPressed: function (e) {
                                if (e.key === Qt.Key_Escape) {
                                    win.visible = false;
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    win.launch();
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Down
                                           || (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier))) {
                                    win.move(1);
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Up
                                           || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) {
                                    win.move(-1);
                                    e.accepted = true;
                                }
                            }

                            // Placeholder prompt when empty.
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text.length === 0
                                text: "Search applications…"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.bodyFontSize
                            }
                        }
                    }
                }
            }

            ListView {
                id: list
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: Theme.popupMargin
                    topMargin: Theme.listSpacing
                }
                clip: true
                model: win.entries
                spacing: Theme.compactSpacing
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 40
                    radius: Theme.smallRadius
                    color: index === win.selected ? Theme.surface : Theme.transparent

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.selected = index
                        onClicked: win.launch()
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.rowSpacing
                        anchors.rightMargin: Theme.rowSpacing
                        spacing: Theme.rowSpacing

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconSize + 6
                            height: Theme.iconSize + 6
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.iconSize - 6 - Theme.rowSpacing
                            spacing: 0

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: modelData.name || ""
                                color: index === win.selected ? Theme.cyan : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.bodyFontSize
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                visible: text.length > 0
                                text: modelData.genericName || modelData.comment || ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.smallFontSize
                            }
                        }
                    }
                }
            }
        }
    }
}
