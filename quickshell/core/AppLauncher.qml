import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Centered, IPC-triggered launcher with two modes sharing one UI:
//   * "apps" — .desktop entries via DesktopEntries (handles Exec field codes /
//     Terminal=true correctly). Trigger: quickshell ipc call launcher toggle
//   * "run"  — executables found on $PATH, run directly (dmenu_run/rofi -show
//     run style). Trigger: quickshell ipc call runner toggle
// Both targets also support show / hide. It themes itself from Theme.qml.
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

    // Active mode: "apps" (.desktop entries) or "run" ($PATH executables).
    property string mode: "apps"

    // Cached list of $PATH executable names, populated by binScan for run mode.
    property var binaries: []

    // Normalized results. Each item: { name, sub, icon, app?, cmd? } where
    // `icon` is an icon name (resolved via Quickshell.iconPath), `app` is a
    // DesktopEntry (apps mode) and `cmd` is a binary name (run mode).
    property var entries: []
    property int selected: 0

    // Number of columns in the results grid (see GridView below).
    readonly property int columns: 2

    // Current search text, mirrored here so refilter() doesn't depend on the
    // window's TextInput still existing (it is destroyed while closed).
    property string searchText: ""

    function refilter() {
        var q = searchText.toLowerCase().trim();
        var out = [];
        if (mode === "run") {
            var bins = binaries;
            for (var i = 0; i < bins.length; i++) {
                var b = bins[i];
                if (q === "" || b.toLowerCase().indexOf(q) >= 0)
                    out.push({ name: b, sub: "", icon: b, cmd: b });
            }
            // bins arrive pre-sorted (sort -u), so no re-sort needed.
        } else {
            var all = DesktopEntries.applications.values;
            for (var j = 0; j < all.length; j++) {
                var e = all[j];
                if (e.noDisplay)
                    continue;
                if (q === ""
                        || (e.name && e.name.toLowerCase().indexOf(q) >= 0)
                        || (e.genericName && e.genericName.toLowerCase().indexOf(q) >= 0)
                        || (e.comment && e.comment.toLowerCase().indexOf(q) >= 0))
                    out.push({ name: e.name || "", sub: e.genericName || e.comment || "", icon: e.icon, app: e });
            }
            out.sort(function (a, b) {
                return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
            });
        }
        entries = out;
        selected = 0;
    }

    function launch() {
        if (selected >= 0 && selected < entries.length) {
            var it = entries[selected];
            if (it.app)
                it.app.execute();
            else if (it.cmd)
                Quickshell.execDetached([it.cmd]);
        }
        shown = false;
    }

    function move(delta) {
        if (entries.length === 0)
            return;
        selected = (selected + delta + entries.length) % entries.length;
    }

    // Open in the given mode ("apps" | "run"), resetting the query.
    function openMode(m) {
        mode = m;
        searchText = "";
        if (m === "run")
            binScan.running = true; // (re)scan $PATH; refilter again when it ends
        refilter();
        shown = true;
    }

    // Toggle: close if already open in this mode, otherwise (re)open in it.
    function toggleMode(m) {
        if (shown && mode === m)
            shown = false;
        else
            openMode(m);
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleMode("apps"); }
        function show(): void { root.openMode("apps"); }
        function hide(): void { root.shown = false; }
    }

    IpcHandler {
        target: "runner"
        function toggle(): void { root.toggleMode("run"); }
        function show(): void { root.openMode("run"); }
        function hide(): void { root.shown = false; }
    }

    // Enumerate executables on $PATH for run mode. StdioCollector buffers the
    // full output (waitForEnd defaults true), so `text` is ready on finish.
    Process {
        id: binScan
        command: ["sh", "-c",
            "for d in $(echo \"$PATH\" | tr ':' ' '); do [ -d \"$d\" ] || continue; for f in \"$d\"/*; do [ -x \"$f\" ] && [ ! -d \"$f\" ] && printf '%s\\n' \"${f##*/}\"; done; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.binaries = text.split("\n").filter(function (s) { return s.length > 0; });
                if (root.shown && root.mode === "run")
                    root.refilter();
            }
        }
    }

    // Re-filter if the application list changes while the apps launcher is open,
    // so the prepopulated list fills in even if entries are still loading.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (root.shown && root.mode === "apps")
                root.refilter();
        }
    }

    // Fullscreen, WM-managed overlay. dwm focuses it (so typing works) and
    // sizes/positions it fullscreen + borderless via the `launchertitle` hook.
    FloatingWindow {
        id: win
        title: "fandwm-launcher"
        screen: root.screen
        visible: root.shown
        // No dim: the overlay is fully transparent, so only the launcher box is
        // visible. It still covers the screen and captures clicks, so clicking
        // anywhere outside the box dismisses the launcher.
        color: "transparent"

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
            width: 820
            height: Math.min(520, 2 * Theme.popupMargin + Theme.buttonHeight
                             + Theme.listSpacing + grid.contentHeight)
            // Pinned near the top and centered horizontally so the search bar
            // stays put; the results list grows/shrinks downward as you type
            // rather than the whole box re-centering vertically.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.height * 0.28)
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
                                    root.move(root.columns);
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Up
                                           || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) {
                                    root.move(-root.columns);
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Right
                                           || (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier))) {
                                    root.move(1);
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Left
                                           || (e.key === Qt.Key_B && (e.modifiers & Qt.ControlModifier))) {
                                    root.move(-1);
                                    e.accepted = true;
                                }
                            }

                            // Placeholder prompt when empty.
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text.length === 0
                                text: root.mode === "run" ? "Run a command…" : "Search applications…"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.bodyFontSize
                            }
                        }
                    }
                }
            }

            GridView {
                id: grid
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
                // Two equal-width columns filling the width, left-to-right, so a
                // row reads <icon> <name> <icon> <name>.
                cellWidth: Math.floor(width / root.columns)
                cellHeight: 48
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.selected
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    // Inset from the cell edges to create the gap between cells.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.compactSpacing / 2
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
                                    text: modelData.sub || ""
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
}
