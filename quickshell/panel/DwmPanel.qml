import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

// The top panel that replaces dwm-qs's built-in bar. dwm-qs reserves a strip
// of Theme.panelHeight px at the top of the screen (config.h `barheight`);
// this window paints into it.
PanelWindow {
    id: root

    required property var state
    required property var clock
    required property var modelData          // ShellScreen, from Variants
    property var primaryNames: []            // output names that may host the tray

    // No `primary` flag on ShellScreen. Tray shows on this screen if its name is
    // listed; if none of the listed names are connected, fall back to the first
    // screen. Lets one list serve multiple machines (laptop vs desktop).
    readonly property bool showTray: {
        var names = primaryNames || [];
        for (var i = 0; i < names.length; i++)
            if (modelData && modelData.name === names[i])
                return true;
        var scr = Quickshell.screens;
        for (var j = 0; j < names.length; j++)
            for (var k = 0; k < scr.length; k++)
                if (scr[k].name === names[j])
                    return false;   // a listed output exists elsewhere → not us
        return scr.length > 0 && modelData && modelData.name === scr[0].name;
    }

    // The dwm monitor record matching this screen (by position). Falls back to
    // global state until per-monitor data arrives.
    readonly property var mon: {
        var ms = root.state.monitors;
        if (ms)
            for (var i = 0; i < ms.length; i++)
                if (ms[i].x === modelData.x && ms[i].y === modelData.y)
                    return ms[i];
        return (ms && ms.length > 0) ? ms[0] : null;
    }

    // Max characters shown for the window title before shortening.
    property int maxTitleLength: 45

    // Shorten an over-long title while keeping the trailing app-name segment
    // (everything after the last " - "). Only the leading part is truncated,
    // so "… - Mozilla Firefox" stays readable instead of losing the app name.
    // Falls back to a plain right-truncation when there's no " - " or the
    // suffix alone already exceeds the budget.
    function shortenTitle(t) {
        var max = root.maxTitleLength;
        if (!t || t.length <= max)
            return t || "";
        var ell = "…";
        var sep = " - ";
        var idx = t.lastIndexOf(sep);
        if (idx > 0) {
            var suffix = t.slice(idx);              // " - Mozilla Firefox"
            var budget = max - suffix.length - ell.length;
            if (budget >= 1)
                return t.slice(0, budget).replace(/\s+$/, "") + ell + suffix;
        }
        return t.slice(0, max - ell.length).replace(/\s+$/, "") + ell;
    }

    screen: modelData
    implicitHeight: Theme.panelHeight
    color: Theme.bg
    aboveWindows: true

    anchors {
        top: true
        left: true
        right: true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.panelPadding
        anchors.rightMargin: Theme.panelPadding
        spacing: Theme.rowSpacing

        // Workspaces (dwm tags)
        Repeater {
            model: root.state.workspaceNames

            delegate: WorkspaceButton {
                required property int index
                required property string modelData

                label: modelData
                selected: root.mon ? ((root.mon.selMask & (1 << index)) !== 0)
                                   : (index === root.state.currentWorkspace)
                occupied: root.mon ? ((root.mon.occMask & (1 << index)) !== 0)
                                   : ((root.state.occupiedMask & (1 << index)) !== 0)
                onClicked: root.state.switchWorkspace(root.mon ? root.mon.num : 0, index)
            }
        }

        // Active layout symbol (e.g. []=, [M], [3]) — per monitor
        Text {
            visible: (root.mon ? root.mon.layout : root.state.layout).length > 0
            text: root.mon ? root.mon.layout : root.state.layout
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelFontSize
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }

        // Focused window title for this monitor, with a leading window icon.
        // Fills the gap between the left group and the status widgets; elides
        // so a long title never pushes the right-hand widgets off screen. The
        // icon is prepended into the same Text so it stays pinned at the front
        // while the title's tail elides, and both vanish when there's no window.
        Text {
            // Nerd Font window glyph shown before the title. Drop your glyph
            // between the quotes (or use a \uXXXX escape). Empty = no icon.
            readonly property string windowIconLeft: "["
            readonly property string windowIconRight: "]"

            Layout.fillWidth: true
            text: (root.mon && root.mon.title && root.mon.title.length > 0)
                  ? (" " + windowIconLeft + " " + root.shortenTitle(root.mon.title) + " " + windowIconRight) : ""
            color: Theme.magenta
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelFontSize
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        // Optional status segments (from root WM_NAME, dwmblocks-style)
        Repeater {
            model: root.state.statusSegments

            delegate: Text {
                required property string modelData
                text: modelData
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelFontSize
                verticalAlignment: Text.AlignVCenter
            }
        }

	// Status/control widgets
	DunstWidget {}
        NetworkWidget {}
        ScriptPill { command: ["dwm-qs-mem"]; interval: 5000; tint: Theme.brightyellow }
        VpnWidget {}
        VolumeWidget {}
        ScriptPill { command: ["dwm-qs-battery"]; interval: 15000 }
        BluetoothWidget {}
        TrayArea {}
        ClockWidget { clock: root.clock }
    }
}
