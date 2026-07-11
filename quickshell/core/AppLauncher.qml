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
// (also: show / hide).
//
// Architecture (X11/dwm):
//   The launcher is a single fullscreen `FloatingWindow`. Unlike PanelWindow
//   (always _NET_WM_WINDOW_TYPE_DOCK, which this dwm maps *unmanaged* and never
//   focuses) and PopupWindow+grabFocus (Qt::Popup / override-redirect, which
//   dwm ignores and Qt does not keyboard-grab), a FloatingWindow is a normal
//   managed top-level. dwm runs it through manage(), so it becomes the selected
//   client and receives keyboard input — and focus is restored to the previous
//   window when it closes, all by the WM's own machinery.
//
//   dwm recognizes this window by its title ("fandwm-launcher", see
//   `launchertitle` in config.def.h) and manages it as a borderless, fullscreen,
//   floating overlay. The whole window is a translucent dim (composited by
//   picom); the interactive box is centered inside it and clicking the dim
//   outside the box dismisses the launcher.
// Everything shows on the primary monitor only (screen set from shell.qml).
Scope {
    id: root

    // Screen the launcher appears on; set from shell.qml (primary monitor).
    property var screen: null

    // Single source of truth for open/closed.
    property bool shown: false

    // Filtered, name-sorted list of visible desktop entries.
    property var entries: []
    property int selected: 0

    // Current search text, mirrored here so refilter() doesn't depend on the
    // window's TextInput still existing (it is destroyed while closed).
    property string searchText: ""

    function refilter() {
        var q = searchText.toLowerCase().trim();
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
        if (selected >= 0 && selected < entries.length)
            entries[selected].execute();
        shown = false;
    }

    function move(delta) {
        if (entries.length === 0)
            return;
        selected = (selected + delta + entries.length) % entries.length;
    }

    onShownChanged: {
        if (shown) {
            searchText = "";
            refilter();
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.shown = !root.shown; }
        function show(): void { root.shown = true; }
        function hide(): void { root.shown = false; }
    }

    // Fullscreen, WM-managed overlay. dwm focuses it (so typing works) and
    // sizes/positions it fullscreen + borderless via the `launchertitle` hook.
    FloatingWindow {
        id: win
        title: "fandwm-launcher"
        screen: root.screen
        visible: root.shown
        color: "#cc1a1b26" // dimmed Tokyo Night backdrop (composited by picom)

        // Size hints; dwm forces the real geometry to the full monitor, but a
        // sane starting size avoids a first-frame flash.
        implicitWidth: root.screen ? root.screen.width : 1280
        implicitHeight: root.screen ? root.screen.height : 720

        // Hand focus to the search field each time we open. Deferred one tick so
        // the window has mapped and dwm has focused it (forceActiveFocus is a
        // no-op while the window is inactive).
        onVisibleChanged: {
            if (visible)
                focusTimer.restart();
        }

        Timer {
            id: focusTimer
            interval: 0
            onTriggered: search.forceActiveFocus()
        }

        // Click on the dim (outside the box) closes the launcher.
        MouseArea {
            anchors.fill: parent
            onClicked: root.shown = false
        }

        Rectangle {
            id: box
            width: 600
            height: Math.min(520, 2 * Theme.popupMargin + Theme.buttonHeight
                             + Theme.listSpacing + list.contentHeight)
            anchors.centerIn: parent
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            radius: Theme.radius

            // Swallow clicks so they don't fall through to the dim (and close).
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
                            text: "" // nerd-font search glyph
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

                            onTextChanged: {
                                root.searchText = text;
                                root.refilter();
                            }

                            Keys.onPressed: function (e) {
                                if (e.key === Qt.Key_Escape) {
                                    root.shown = false;
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    root.launch();
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Down
                                           || (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier))) {
                                    root.move(1);
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Up
                                           || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) {
                                    root.move(-1);
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
                model: root.entries
                spacing: Theme.compactSpacing
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.selected
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 40
                    radius: Theme.smallRadius
                    color: index === root.selected ? Theme.surface : Theme.transparent

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selected = index
                        onClicked: root.launch()
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
                                color: index === root.selected ? Theme.cyan : Theme.text
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
