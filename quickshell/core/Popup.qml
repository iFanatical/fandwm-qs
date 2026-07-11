import QtQuick
import Quickshell
import qs.core

// A themed dropdown popup anchored under a bar item. Set `anchorItem` to the
// BarPill, size via popupWidth/popupHeight, and toggle `visible`. Closes on
// Escape; grabs focus so it behaves like a menu.
PopupWindow {
    id: root
    property Item anchorItem
    property int popupWidth: 320
    property int popupHeight: 400
    default property alias content: surface.content

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: anchorItem ? anchorItem.height + 4 : 0

    implicitWidth: popupWidth
    implicitHeight: popupHeight
    color: Theme.transparent
    grabFocus: true
    visible: false

    onVisibleChanged: {
        if (visible) PopupManager.opened(root);
        else PopupManager.closed(root);
    }

    ShellSurface {
        id: surface
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (e) {
            if (e.key === Qt.Key_Escape)
                root.visible = false;
        }
    }
}
