import QtQuick
import Quickshell
import qs.core

// A themed context menu built from a QsMenuHandle's entries (QsMenuOpener),
// instead of QsMenuAnchor's native platform menu. Recurses for submenus.
PopupWindow {
    id: root
    property var menuHandle            // QsMenuHandle (SystemTrayItem.menu or a submenu entry)
    property Item anchorItem
    property int anchorX: 0
    property int anchorY: anchorItem ? anchorItem.height : 0
    property var _submenuComp: null    // lazily-created component for submenus
    property bool topLevel: true       // false for dynamically-created submenus
    property var _subs: []             // submenu instances, closed when we hide
    signal dismissed()

    function dismiss() {
        visible = false;
        dismissed();
    }

    onVisibleChanged: {
        if (topLevel) {
            if (visible) PopupManager.opened(root);
            else PopupManager.closed(root);
        }
        if (!visible) {
            for (var i = 0; i < _subs.length; i++)
                if (_subs[i]) _subs[i].visible = false;
        }
    }

    anchor.item: anchorItem
    anchor.rect.x: anchorX
    anchor.rect.y: anchorY
    implicitWidth: 240
    implicitHeight: menuCol.implicitHeight + 8
    color: Theme.transparent
    grabFocus: true
    visible: false

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.smallRadius
        focus: true
        Keys.onPressed: function (e) {
            if (e.key === Qt.Key_Escape)
                root.dismiss();
        }

        Column {
            id: menuCol
            x: 4
            y: 4
            width: parent.width - 8
            spacing: 1

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entry
                    required property var modelData
                    property var submenu: null
                    width: menuCol.width
                    height: modelData.isSeparator ? 7 : 26

                    // separator
                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        height: 1
                        color: Theme.border
                    }

                    // menu item
                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: Theme.smallRadius
                        color: (rowMouse.containsMouse && entry.modelData.enabled) ? Theme.surfaceHover : "transparent"

                        Text {
                            id: checkMark
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: entry.modelData.buttonType !== QsMenuButtonType.None ? 14 : 0
                            visible: entry.modelData.buttonType !== QsMenuButtonType.None
                            text: entry.modelData.checkState === Qt.Checked
                                  ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "" : "")
                                  : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "" : "")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                        }
                        Image {
                            id: entryIcon
                            anchors.left: checkMark.right
                            anchors.leftMargin: entry.modelData.icon.length > 0 ? 6 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: entry.modelData.icon.length > 0 ? 16 : 0
                            height: 16
                            visible: entry.modelData.icon.length > 0
                            source: entry.modelData.icon
                            sourceSize.width: 16
                            sourceSize.height: 16
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            anchors.left: entryIcon.right
                            anchors.leftMargin: 8
                            anchors.right: arrow.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.text
                            color: entry.modelData.enabled ? Theme.text : Theme.textMuted
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                        }
                        Text {
                            id: arrow
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entry.modelData.hasChildren
                            text: entry.modelData.hasChildren ? "" : ""
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    if (!entry.submenu) {
                                        // recursive type: instantiate at runtime by URL
                                        if (!root._submenuComp)
                                            root._submenuComp = Qt.createComponent(Qt.resolvedUrl("TrayMenu.qml"));
                                        if (root._submenuComp.status === Component.Ready) {
                                            entry.submenu = root._submenuComp.createObject(root, {
                                                menuHandle: entry.modelData,
                                                anchorItem: entry,
                                                anchorX: entry.width - 6,
                                                anchorY: 0,
                                                topLevel: false
                                            });
                                            if (entry.submenu) {
                                                entry.submenu.dismissed.connect(root.dismiss);
                                                root._subs.push(entry.submenu);
                                            }
                                        }
                                    }
                                    if (entry.submenu)
                                        entry.submenu.visible = true;
                                } else {
                                    entry.modelData.triggered();
                                    root.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
