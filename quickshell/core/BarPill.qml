import QtQuick
import QtQuick.Layouts
import qs.core

// A clickable panel item: an optional Nerd Font glyph + optional label.
// Emits clicked / rightClicked / scrolled(delta) for widget interaction.
Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    // When true the label is parsed as StyledText, so `<font color>` spans can
    // colour parts of it independently. Off by default: plain labels (SSIDs,
    // clocks, …) may contain characters StyledText would misinterpret.
    property bool richLabel: false
    property color tint: Theme.text
    property bool active: false
    signal clicked()
    signal rightClicked()
    signal scrolled(int delta)   // +1 = up/away, -1 = down/toward

    Layout.preferredHeight: Theme.pillHeight
    implicitWidth: rowl.implicitWidth + 16
    Layout.preferredWidth: implicitWidth
    radius: Theme.radius
    // Persistent chip, like the active tag's highlight: a surface box (never the
    // bar background), lighter on hover/open, with a cyan border when open.
    readonly property bool highlighted: mouse.containsMouse || root.active
    color: highlighted ? Theme.surfaceHover : Theme.surface
    border.width: root.active ? 1 : 0
    border.color: Theme.accent

    RowLayout {
        id: rowl
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.highlighted ? Theme.tagActive : root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelFontSize
        }
        Text {
            visible: root.label.length > 0
            text: root.label
            textFormat: root.richLabel ? Text.StyledText : Text.PlainText
            color: root.highlighted ? Theme.tagActive : root.tint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelFontSize
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (e) {
            if (e.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
        onWheel: function (w) {
            root.scrolled(w.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
