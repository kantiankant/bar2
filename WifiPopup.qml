import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: wifiPopupWindow
        property var modelData
        screen: modelData
        visible: root._wifiActualVisible
        anchors.top:    root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"
        anchors.right:  true
        margins { top: root.barEdge !== "bottom" ? 66 : 0; bottom: root.barEdge === "bottom" ? 66 : 0; right: 12 }
        implicitWidth: 320; implicitHeight: Math.min(wifiPopupCol.implicitHeight + 32, screen ? screen.height * 0.75 : 600)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        property bool _closing: false
        function closeWifi() {
            if (_closing || !visible) return
            _closing = true
            root.wifiPopupVisible = false
            wifiFadeOut.start(); wifiSlideOut.start()
        }

        // Pill button lives in a different Variants scope — it signals via root flag
        Connections {
            target: root
            function on_wifiCloseRequestedChanged() {
                if (root._wifiCloseRequested) {
                    root._wifiCloseRequested = false
                    wifiPopupWindow.closeWifi()
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                _closing = false
                wifiAnimItem.opacity = 0.0
                wifiSlide.y = root.slideDir * root.slideDistance
                wifiFadeIn.start(); wifiSlideIn.start()
            }
        }

        NumberAnimation { id: wifiFadeIn;  target: wifiAnimItem; property: "opacity"; from: 0.0; to: 1.0; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
        NumberAnimation { id: wifiSlideIn; target: wifiSlide;    property: "y";       to: 0;               duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
        NumberAnimation { id: wifiFadeOut;  target: wifiAnimItem; property: "opacity"; to: 0.0;             duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut
            onFinished: { root._wifiActualVisible = false; wifiPopupWindow._closing = false } }
        NumberAnimation { id: wifiSlideOut; target: wifiSlide;    property: "y"; to: root.slideDir * root.slideDistance; duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut }

        Item {
            id: wifiAnimItem
            anchors.fill: parent; opacity: 0.0
            transform: Translate { id: wifiSlide; y: root.slideDir * root.slideDistance }

            Rectangle {
                anchors.fill: parent; radius: root.panelRadius
                color: Qt.rgba(0.06,0.07,0.10,0.55); border.color: Qt.rgba(1,1,1,0.09); border.width: 1
                Rectangle { anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                    width: parent.width * 0.5; height: 1; color: Qt.rgba(1,1,1,0.15); radius: 1 }
            }

            Flickable {
                anchors.fill: parent; anchors.margins: 16
                contentHeight: wifiPopupCol.implicitHeight; clip: true
                ScrollBar.vertical: ScrollBar {
                    policy: parent.contentHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    width: 3
                    contentItem: Rectangle { radius: 1.5; color: Qt.rgba(1,1,1,0.22) }
                    background: Rectangle { color: "transparent" }
                }

                Column {
                    id: wifiPopupCol; width: parent.width; spacing: 0

                    // ── Header ──────────────────────────────────────────────
                    RowLayout { width: parent.width; height: 30
                        RowLayout { spacing: 7
                            Text { text: "\uf1eb"; font.family: "Symbols Nerd Font"; font.pixelSize: 13; color: Qt.rgba(1,1,1,0.40) }
                            Text { text: "WiFi"; font.family: "SF Pro Display"; font.pixelSize: 12; font.weight: Font.SemiBold; color: "white" }
                            Rectangle {
                                visible: root.wifiSsid.length > 0; radius: root.pillRadius; height: 16
                                implicitWidth: connectedBadge.implicitWidth + 12
                                color: Qt.rgba(0.20,0.78,0.35,0.18); border.color: Qt.rgba(0.20,0.78,0.35,0.30); border.width: 1
                                Text { id: connectedBadge; anchors.centerIn: parent; text: root.wifiSsid; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(0.50,1.0,0.60,0.90); elide: Text.ElideRight }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        // Scan button
                        Item { implicitWidth: 22; implicitHeight: 22
                            Rectangle { id: wifiScanBg; anchors.fill: parent; radius: 11; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                            Text { anchors.centerIn: parent; text: "\uf021"; font.family: "Symbols Nerd Font"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.35)
                                RotationAnimation on rotation { running: root.wifiScanning; from: 0; to: 360; duration: 900; loops: Animation.Infinite } }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: wifiScanBg.color = Qt.rgba(1,1,1,0.10); onExited: wifiScanBg.color = Qt.rgba(1,1,1,0.0); onClicked: root.wifiStartScan() }
                        }
                        Item { implicitWidth: 6 }
                        // Close button
                        Item { implicitWidth: 22; implicitHeight: 22
                            Rectangle { id: wifiCloseBg; anchors.fill: parent; radius: 11; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                            Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: wifiCloseBg.color = Qt.rgba(1,1,1,0.10); onExited: wifiCloseBg.color = Qt.rgba(1,1,1,0.0); onClicked: wifiPopupWindow.closeWifi() }
                        }
                    }

                    Item { width: 1; height: 8 }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
                    Item { width: 1; height: 8 }

                    // ── Status message ──────────────────────────────────────
                    Item {
                        width: parent.width; height: 24
                        visible: root.wifiConnectMsg.length > 0
                        Rectangle { anchors.fill: parent; radius: root.pillRadius
                            color: root.wifiConnectMsg.startsWith("✓") ? Qt.rgba(0.20,0.78,0.35,0.15) : root.wifiConnectMsg.startsWith("✕") ? Qt.rgba(0.90,0.30,0.25,0.15) : Qt.rgba(1,1,1,0.05)
                            border.color: root.wifiConnectMsg.startsWith("✓") ? Qt.rgba(0.20,0.78,0.35,0.30) : root.wifiConnectMsg.startsWith("✕") ? Qt.rgba(0.90,0.30,0.25,0.30) : Qt.rgba(1,1,1,0.08); border.width: 1
                        }
                        Text { anchors.centerIn: parent; text: root.wifiConnectMsg; font.family: "SF Pro Display"; font.pixelSize: 10
                            color: root.wifiConnectMsg.startsWith("✓") ? Qt.rgba(0.50,1.0,0.60,0.90) : root.wifiConnectMsg.startsWith("✕") ? Qt.rgba(1.0,0.55,0.50,0.90) : Qt.rgba(1,1,1,0.55)
                            elide: Text.ElideRight; width: parent.width - 20 }
                    }
                    Item { width: 1; height: root.wifiConnectMsg.length > 0 ? 8 : 0 }

                    // ── Empty / scanning state ──────────────────────────────
                    Item {
                        width: parent.width; height: 80
                        visible: root.wifiScanning || (!root.wifiScanning && root.wifiNetworks.length === 0)
                        Column { anchors.centerIn: parent; spacing: 6
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: root.wifiScanning ? "\uf021" : "\uf204"
                                font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: Qt.rgba(1,1,1,0.25)
                                RotationAnimation on rotation { running: root.wifiScanning; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                text: root.wifiScanning ? "Scanning…" : "No networks found"
                                font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.25) }
                        }
                    }

                    // ── Network list ────────────────────────────────────────
                    Column {
                        width: parent.width; spacing: 4
                        visible: !root.wifiScanning && root.wifiNetworks.length > 0

                        Repeater {
                            model: root.wifiNetworks
                            delegate: Item {
                                required property var modelData; required property int index
                                width: parent.width
                                property bool isConnected: modelData.connected || modelData.ssid === root.wifiSsid
                                property bool isSecured:   modelData.security.length > 0 && modelData.security !== "--"
                                property bool isExpanded:  root.wifiExpandedSsid === modelData.ssid
                                height: isExpanded ? 116 : 38
                                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                clip: true

                                // Row background
                                Rectangle {
                                    id: netRowBg; x: 0; y: 0; width: parent.width; height: 38; radius: root.pillRadius
                                    color: isConnected ? Qt.rgba(0.20,0.78,0.35,0.14) : netHover.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                                    border.color: isConnected ? Qt.rgba(0.20,0.78,0.35,0.28) : isExpanded ? Qt.rgba(0.42,0.68,1.0,0.30) : Qt.rgba(1,1,1,0.07); border.width: 1
                                    Behavior on color       { ColorAnimation { duration: 110 } }
                                    Behavior on border.color { ColorAnimation { duration: 110 } }
                                }

                                // Row content
                                RowLayout {
                                    x: 0; y: 0; width: parent.width; height: 38
                                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
                                    spacing: 10

                                    // Signal bars
                                    Row { spacing: 2
                                        Repeater { model: 4
                                            delegate: Rectangle {
                                                width: 3; height: 4 + index * 3; radius: 1
                                                anchors.bottom: parent ? parent.bottom : undefined
                                                color: {
                                                    if (modelData.signal < (index + 1) * 25) return Qt.rgba(1,1,1,0.15)
                                                    return isConnected ? Qt.rgba(0.30,0.90,0.45,0.90) : isExpanded ? Qt.rgba(0.72,0.88,1.0,0.85) : Qt.rgba(1,1,1,0.70)
                                                }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }
                                    }

                                    Text { Layout.fillWidth: true; text: modelData.ssid
                                        font.family: "SF Pro Display"; font.pixelSize: 12
                                        font.weight: (isConnected || isExpanded) ? Font.SemiBold : Font.Normal
                                        color: isConnected ? Qt.rgba(0.50,1.0,0.60,0.95) : isExpanded ? Qt.rgba(0.72,0.88,1.0,0.95) : "white"
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 110 } }
                                    }
                                    Text { visible: isSecured;    text: "\uf023"; font.family: "Symbols Nerd Font"; font.pixelSize: 10; color: isExpanded ? Qt.rgba(0.72,0.88,1.0,0.55) : Qt.rgba(1,1,1,0.28) }
                                    Text { visible: isConnected;  text: "\uf00c"; font.family: "Symbols Nerd Font"; font.pixelSize: 10; color: Qt.rgba(0.30,0.90,0.45,0.90) }
                                    Text { visible: isExpanded && !isConnected; text: "\uf077"; font.family: "Symbols Nerd Font"; font.pixelSize: 9; color: Qt.rgba(0.72,0.88,1.0,0.50) }
                                }

                                MouseArea {
                                    id: netHover; x: 0; y: 0; width: parent.width; height: 38
                                    propagateComposedEvents: true; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (isConnected) return
                                        if (isSecured) { root.wifiExpandedSsid = isExpanded ? "" : modelData.ssid; root.wifiPasswordInput = ""; root.wifiConnectMsg = "" }
                                        else           { root.wifiConnect(modelData.ssid, "") }
                                    }
                                }

                                // Password drawer (slides in when isExpanded)
                                Item {
                                    x: 0; y: 44; width: parent.width; height: 68
                                    opacity: isExpanded ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 160 } }

                                    Rectangle { anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(0.08,0.10,0.16,1.0); border.color: Qt.rgba(0.42,0.68,1.0,0.22); border.width: 1 }
                                    Column { anchors { fill: parent; margins: 10 } spacing: 7
                                        RowLayout { width: parent.width; height: 28; spacing: 8
                                            Text { text: "\uf023"; font.family: "Symbols Nerd Font"; font.pixelSize: 11; color: Qt.rgba(0.72,0.88,1.0,0.50) }
                                            Rectangle { Layout.fillWidth: true; height: 28; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.07)
                                                border.color: pwInput.activeFocus ? Qt.rgba(0.42,0.68,1.0,0.55) : Qt.rgba(1,1,1,0.10); border.width: 1
                                                Behavior on border.color { ColorAnimation { duration: 130 } }
                                                TextInput {
                                                    id: pwInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                                    verticalAlignment: TextInput.AlignVCenter; echoMode: TextInput.Password
                                                    font.family: "SF Pro Display"; font.pixelSize: 12; color: "white"
                                                    selectionColor: Qt.rgba(0.42,0.68,1.0,0.35)
                                                    onTextChanged: root.wifiPasswordInput = text
                                                    onAccepted: { if (text.length > 0) { root.wifiConnect(modelData.ssid, text); root.wifiExpandedSsid = "" } }
                                                }
                                                Text {
                                                    anchors { fill: parent; leftMargin: 10 }
                                                    verticalAlignment: Text.AlignVCenter
                                                    visible: pwInput.text.length === 0 && !pwInput.activeFocus
                                                    text: "Password…"; font.family: "SF Pro Display"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.25)
                                                }
                                            }
                                            // Connect arrow
                                            Item { implicitWidth: 32; implicitHeight: 28
                                                Rectangle { id: pwConnBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(0.42,0.68,1.0,0.22); border.color: Qt.rgba(0.42,0.68,1.0,0.30); border.width: 1; Behavior on color { ColorAnimation { duration: 110 } } }
                                                Text { anchors.centerIn: parent; text: "\uf061"; font.family: "Symbols Nerd Font"; font.pixelSize: 12; color: Qt.rgba(0.72,0.88,1.0,0.90) }
                                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: pwConnBg.color = Qt.rgba(0.42,0.68,1.0,0.38); onExited: pwConnBg.color = Qt.rgba(0.42,0.68,1.0,0.22)
                                                    onClicked: { if (root.wifiPasswordInput.length > 0) { root.wifiConnect(modelData.ssid, root.wifiPasswordInput); root.wifiExpandedSsid = "" } }
                                                }
                                            }
                                            // Cancel X
                                            Item { implicitWidth: 28; implicitHeight: 28
                                                Rectangle { id: pwCancelBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.05); border.color: Qt.rgba(1,1,1,0.09); border.width: 1; Behavior on color { ColorAnimation { duration: 110 } } }
                                                Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: pwCancelBg.color = Qt.rgba(1,1,1,0.10); onExited: pwCancelBg.color = Qt.rgba(1,1,1,0.05)
                                                    onClicked: { root.wifiExpandedSsid = ""; root.wifiPasswordInput = "" }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 10 }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
                    Item { width: 1; height: 8 }
                    Text { text: "iwctl · click to connect"; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.16) }
                    Item { width: 1; height: 4 }
                }
            }
        }
    }
}
