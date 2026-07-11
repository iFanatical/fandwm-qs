import QtQuick
import Quickshell
import qs.core

Popup {
    id: root
    property var net                 // NetworkState
    property string selectedSsid: "" // wifi row expanded for password entry

    popupWidth: 360
    popupHeight: Math.min(560, col.implicitHeight + 2 * Theme.popupMargin)

    readonly property bool isNm: (net?.backend ?? "ip") === "nm"

    onVisibleChanged: if (visible && isNm) net.refreshWifi()

    function secured(sec) { return sec && sec.length > 0 && sec !== "--"; }
    function sigGlyph(s) {
        return s >= 75 ? "󰤨" : s >= 50 ? "󰤥" : s >= 25 ? "󰤢" : s > 0 ? "󰤟" : "󰤯";
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.popupSpacing

        // ---- header ----
        Item {
            width: parent.width
            height: hdrRight.height
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.isNm ? "Network" : "Network (wired)"
                color: Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.bodyFontSize
                font.bold: true
            }
            Row {
                id: hdrRight
                anchors.right: parent.right
                spacing: 8
                ShellButton {
                    visible: root.isNm
                    label: (root.net?.wifiEnabled ?? false) ? "Wi-Fi On" : "Wi-Fi Off"
                    active: root.net?.wifiEnabled ?? false
                    onActivated: root.net?.setRadio(!(root.net?.wifiEnabled ?? false))
                }
                ShellButton {
                    visible: root.isNm
                    label: (root.net?.scanning ?? false) ? "Scanning…" : "Scan"
                    enabled: root.net?.wifiEnabled ?? false
                    onActivated: root.net?.wifiScan()
                }
                ShellButton {
                    visible: !root.isNm
                    label: "Re-apply"
                    onActivated: root.net?.reapply()
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // ---- active-connection summary ----
        Column {
            width: parent.width
            spacing: 1
            Text {
                text: {
                    if (root.isNm) {
                        if (root.net?.kind === "wifi") return " " + (root.net?.ssid || "—");
                        if (root.net?.kind === "ethernet") return "󰈀 " + (root.net?.connName || "Wired");
                        return "󰤮 Disconnected";
                    }
                    return "󰈀 " + (root.net?.device || "—");
                }
                color: (root.net?.online ?? false) ? Theme.success : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                font.bold: true
            }
            Text {
                text: (root.net?.ip4 || root.net?.gateway)
                      ? ("IP " + (root.net?.ip4 || "—") + "   GW " + (root.net?.gateway || "—"))
                      : "no address"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.tinyFontSize
            }
        }

        // ================= NetworkManager: Wi-Fi list =================
        Repeater {
            model: root.isNm ? (root.net?.wifiNetworks ?? []) : []
            delegate: Column {
                id: wifiEntry
                required property var modelData
                width: col.width
                readonly property bool sel: root.selectedSsid === modelData.ssid
                readonly property bool sec: root.secured(modelData.security)

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: Theme.smallRadius
                    color: wifiMouse.containsMouse ? Theme.surfaceHover
                         : (wifiEntry.modelData.active ? Theme.surface : "transparent")

                    Text {
                        id: sigIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sigGlyph(wifiEntry.modelData.signal)
                        color: wifiEntry.modelData.active ? Theme.accent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.bodyFontSize
                    }
                    Column {
                        anchors.left: sigIcon.right
                        anchors.leftMargin: 8
                        anchors.right: actionChip.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: (wifiEntry.sec ? "" : "") + " " + wifiEntry.modelData.ssid
                            color: Theme.text
                            elide: Text.ElideRight
                            width: parent.width
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                        }
                        Text {
                            text: (wifiEntry.sec ? (wifiEntry.modelData.security + " ") : "Open ")
                                  + "· " + wifiEntry.modelData.signal + "%"
                            color: wifiEntry.modelData.active ? Theme.success : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.tinyFontSize
                        }
                    }
                    ShellButton {
                        id: actionChip
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        label: wifiEntry.modelData.active ? "Disconnect" : "Connect"
                        danger: wifiEntry.modelData.active
                        onActivated: {
                            if (wifiEntry.modelData.active) { root.net.wifiDisconnect(); return; }
                            if (wifiEntry.sec)
                                root.selectedSsid = (root.selectedSsid === wifiEntry.modelData.ssid ? "" : wifiEntry.modelData.ssid);
                            else
                                root.net.wifiConnect(wifiEntry.modelData.ssid, "");
                        }
                    }
                    MouseArea {
                        id: wifiMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                // password entry, shown for a selected secured network
                Rectangle {
                    width: parent.width
                    height: (wifiEntry.sel && wifiEntry.sec) ? 32 : 0
                    visible: wifiEntry.sel && wifiEntry.sec
                    radius: Theme.smallRadius
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    TextInput {
                        id: pwInput
                        anchors.left: parent.left
                        anchors.right: joinBtn.left
                        anchors.margins: 8
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.Password
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                        clip: true
                        Text {
                            anchors.fill: parent
                            visible: pwInput.text.length === 0
                            text: "password"
                            color: Theme.textMuted
                            verticalAlignment: Text.AlignVCenter
                            font: pwInput.font
                        }
                        onAccepted: { root.net.wifiConnect(wifiEntry.modelData.ssid, text); root.selectedSsid = ""; }
                    }
                    ShellButton {
                        id: joinBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Join"
                        onActivated: { root.net.wifiConnect(wifiEntry.modelData.ssid, pwInput.text); root.selectedSsid = ""; }
                    }
                }
            }
        }

        Text {
            visible: root.isNm && (root.net?.wifiNetworks?.length ?? 0) === 0
            text: (root.net?.wifiEnabled ?? false) ? "No networks — hit Scan." : "Wi-Fi is off."
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
        }

        // ================= iproute2: link/bridge/VLAN status =================
        Repeater {
            model: root.isNm ? [] : (root.net?.links ?? [])
            delegate: Rectangle {
                id: linkEntry
                required property var modelData
                width: col.width
                height: 34
                radius: Theme.smallRadius
                readonly property bool linkUp: modelData.state === "UP"
                color: linkMouse.containsMouse ? Theme.surfaceHover : "transparent"

                Column {
                    anchors.left: parent.left
                    anchors.right: toggleBtn.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: linkEntry.modelData.name + "  " + (linkEntry.modelData.addr || "")
                        color: linkEntry.linkUp ? Theme.text : Theme.textMuted
                        elide: Text.ElideRight
                        width: parent.width
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                    }
                    Text {
                        text: linkEntry.modelData.type + " · " + linkEntry.modelData.state
                        color: linkEntry.linkUp ? Theme.success : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.tinyFontSize
                    }
                }
                ShellButton {
                    id: toggleBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    label: linkEntry.linkUp ? "Down" : "Up"
                    danger: linkEntry.linkUp
                    onActivated: linkEntry.linkUp ? root.net.linkDown(linkEntry.modelData.name)
                                                  : root.net.linkUp(linkEntry.modelData.name)
                }
                MouseArea {
                    id: linkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
