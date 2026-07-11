import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

// One StatusNotifierItem (D-Bus / SNI) tray icon.
Rectangle {
    id: root

    required property var trayItem

    Layout.preferredWidth: Theme.trayItemSize
    Layout.preferredHeight: Theme.trayItemSize
    radius: Theme.smallRadius
    color: mouse.containsMouse ? Theme.surface : "transparent"

    // Themed context menu (built from the SNI menu model), not the native one.
    TrayMenu {
        id: trayMenu
        menuHandle: root.trayItem ? root.trayItem.menu : null
        anchorItem: root
    }

    function openMenu() {
        if (root.trayItem && root.trayItem.hasMenu)
            trayMenu.visible = !trayMenu.visible;
    }

    Image {
        id: icon
        anchors.centerIn: parent
        width: Theme.trayIconSize
        height: Theme.trayIconSize
        source: root.trayItem ? root.trayItem.icon : ""
        sourceSize.width: Theme.trayIconSize
        sourceSize.height: Theme.trayIconSize
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: !icon.visible
        text: {
            const t = root.trayItem
                ? (root.trayItem.tooltipTitle || root.trayItem.title || root.trayItem.id || "?")
                : "?";
            return t.length > 0 ? t.charAt(0).toUpperCase() : "?";
        }
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.tinyFontSize
        font.bold: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (ev) {
            if (!root.trayItem)
                return;
            if (ev.button === Qt.LeftButton) {
                // Toggle the themed menu when the app has one; otherwise
                // trigger its primary action.
                if (root.trayItem.hasMenu)
                    root.openMenu();
                else if (root.trayItem.activate)
                    root.trayItem.activate();
            } else if (ev.button === Qt.MiddleButton) {
                if (root.trayItem.secondaryActivate)
                    root.trayItem.secondaryActivate();
            } else if (ev.button === Qt.RightButton) {
                root.openMenu();
            }
        }
    }
}
