import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ─── Main bar + the three popups that live inside its Variants scope ──────────
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: panelWindow
        property var modelData
        screen: modelData

        anchors.top:    root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"
        anchors.left:   true
        anchors.right:  true
        margins {
            top:    root.barEdge === "top"    ? 10 : 0
            bottom: root.barEdge === "bottom" ? 10 : 0
            left:   12; right: 12
        }
        implicitHeight: 46
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: 56

        // ── Background pill ────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent; radius: root.panelRadius
            color: Qt.rgba(0.07, 0.08, 0.10, 0.35)
            border.color: Qt.rgba(1,1,1,0.09); border.width: 1
            Rectangle {
                x: (parent.width - width) / 2
                y: root.barEdge === "bottom" ? parent.height - 2 : 1
                width: parent.width * 0.45; height: 1; radius: 1
                color: Qt.rgba(1,1,1,0.18)
            }
        }

        // ── Centre clock ───────────────────────────────────────────────────
        Item {
            anchors.centerIn: parent
            implicitWidth: clockCol.implicitWidth + 24; implicitHeight: 36

            Rectangle {
                id: clockHoverBg; anchors.fill: parent; radius: root.squircleRadius
                color: Qt.rgba(1,1,1,0.0)
                Behavior on color { ColorAnimation { duration: 130 } }
            }
            Column {
                id: clockCol; anchors.centerIn: parent; spacing: 1
                Text {
                    text: root.clockTime; font.pixelSize: 13; font.family: "SF Pro Display"
                    font.weight: Font.Medium; color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: root.clockDate; font.pixelSize: 10; font.family: "SF Pro Display"
                    color: Qt.rgba(1,1,1,0.45)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: clockHoverBg.color = Qt.rgba(1,1,1,0.07)
                onExited:  clockHoverBg.color = Qt.rgba(1,1,1,0.0)
                onClicked: {
                    if (calendarPopupWindow.visible) calendarPopupWindow.closeCalendar()
                    else {
                        root.calYear  = new Date().getFullYear()
                        root.calMonth = new Date().getMonth()
                        calendarPopupWindow.visible = true
                    }
                }
            }
        }

        // ── Left + Right clusters ──────────────────────────────────────────
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 0

            // ── Left cluster ───────────────────────────────────────────────
            RowLayout {
                spacing: 8

                // Hyprland logo → settings
                Item {
                    implicitWidth: 28; implicitHeight: 28
                    Rectangle {
                        id: logoHoverBg; anchors.fill: parent; radius: root.squircleRadius
                        color: Qt.rgba(1,1,1,0.0)
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    Text {
                        anchors.centerIn: parent; text: "\uf32e"
                        font.family: "Symbols Nerd Font"; font.pixelSize: 18; color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: logoHoverBg.color = Qt.rgba(1,1,1,0.10)
                        onExited:  logoHoverBg.color = Qt.rgba(1,1,1,0.0)
                        onClicked: {
                            if (settingsPopupWindow.visible) settingsPopupWindow.closeSettings()
                            else settingsPopupWindow.visible = true
                        }
                    }
                }

                Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.10); radius: 1 }

                // Workspaces 1–9
                RowLayout {
                    spacing: 3
                    Repeater {
                        model: 9
                        delegate: Item {
                            implicitWidth: 26; implicitHeight: 30
                            property bool isFoc: Hyprland.focusedWorkspace !== null &&
                                                 Hyprland.focusedWorkspace.id === (index + 1)
                            property bool isOcc: {
                                for (var i = 0; i < Hyprland.workspaces.length; i++)
                                    if (Hyprland.workspaces[i].id === (index + 1)) return true
                                return false
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: isFoc ? 24 : 20; height: width
                                radius: root.squircleRadius * (isFoc ? 1 : 0.8)
                                color: isFoc ? Qt.rgba(1,1,1,0.14) : isOcc ? Qt.rgba(1,1,1,0.05) : "transparent"
                                border.color: isOcc && !isFoc ? Qt.rgba(1,1,1,0.12) : "transparent"; border.width: 1
                                Behavior on width  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on color  { ColorAnimation  { duration: 180 } }
                            }
                            Text {
                                anchors.centerIn: parent; text: index + 1
                                font.pixelSize: 11; font.family: "SF Pro Display"
                                color: isFoc ? "white" : isOcc ? Qt.rgba(1,1,1,0.75) : Qt.rgba(1,1,1,0.28)
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.switchWorkspace(index + 1) }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // ── Right cluster (RTL so battery is rightmost) ────────────────
            RowLayout {
                layoutDirection: Qt.RightToLeft; spacing: 12

                // Battery
                RowLayout {
                    spacing: 5
                    Text { text: root.batCharging ? "\uf0e7" : "\uf240"; font.family: "Symbols Nerd Font"; font.pixelSize: 13; color: root.batColor }
                    Text { text: root.batCapacity + "%"; font.pixelSize: 12; font.family: "SF Pro Display"; color: root.batColor }
                }

                // WiFi pill
                Item {
                    implicitWidth: wifiPillRow.implicitWidth + 18; implicitHeight: 30
                    Rectangle {
                        id: wifiPillBg; anchors.fill: parent; radius: root.squircleRadius
                        color: Qt.rgba(1,1,1,0.0)
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    RowLayout {
                        id: wifiPillRow; anchors.centerIn: parent; spacing: 6
                        Row {
                            spacing: 2
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    width: 3; height: 4 + index * 3; radius: 1
                                    anchors.bottom: parent ? parent.bottom : undefined
                                    color: root.wifiSsid.length === 0 ? Qt.rgba(1,1,1,0.15) :
                                           root.wifiSignal >= (index + 1) * 25 ? "white" : Qt.rgba(1,1,1,0.20)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }
                        Text {
                            text: root.wifiSsid.length > 0 ? root.wifiSsid : "No WiFi"
                            font.family: "SF Pro Display"; font.pixelSize: 12
                            color: root.wifiSsid.length > 0 ? "white" : Qt.rgba(1,1,1,0.35)
                            elide: Text.ElideRight; Layout.maximumWidth: 120
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: wifiPillBg.color = Qt.rgba(1,1,1,0.08)
                        onExited:  wifiPillBg.color = Qt.rgba(1,1,1,0.0)
                        onClicked: {
                            if (root._wifiActualVisible) root.requestCloseWifi()
                            else { root.wifiPopupVisible = true; root.wifiStartScan() }
                        }
                    }
                }

                // Weather pill
                Item {
                    implicitWidth: weatherRow.implicitWidth + 18; implicitHeight: 30
                    Rectangle {
                        id: weatherHoverBg; anchors.fill: parent; radius: root.squircleRadius
                        color: Qt.rgba(1,1,1,0.0)
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    RowLayout {
                        id: weatherRow; anchors.centerIn: parent; spacing: 6
                        Text { text: root.weatherIcon; font.pixelSize: 16 }
                        Text { text: root.weatherTemp; font.pixelSize: 12; font.family: "SF Pro Display"; color: "white" }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: weatherHoverBg.color = Qt.rgba(1,1,1,0.08)
                        onExited:  weatherHoverBg.color = Qt.rgba(1,1,1,0.0)
                        onClicked: {
                            if (weatherPopupWindow.visible) weatherPopupWindow.closeWeather()
                            else { if (root.weatherNeedsRefresh()) root.fetchWeatherFull(); weatherPopupWindow.visible = true }
                        }
                    }
                }

                // Music pill
                Item {
                    implicitWidth: musicPillRow.implicitWidth + 18; implicitHeight: 30
                    Rectangle {
                        id: musicPillBg; anchors.fill: parent; radius: root.squircleRadius
                        color: Qt.rgba(1,1,1,0.0)
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    RowLayout {
                        id: musicPillRow; anchors.centerIn: parent; spacing: 7
                        Row {
                            spacing: 2
                            Repeater {
                                model: 5
                                delegate: Rectangle {
                                    width: 2; radius: 1
                                    color: root.musicStatus === "Playing" ? Qt.rgba(0.72,0.88,1.0,0.85) : Qt.rgba(1,1,1,0.30)
                                    height: root.musicStatus === "Playing" ? Math.max(4, root.cavaHeights[index * 3] * 14) : 6
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                                    Behavior on color  { ColorAnimation  { duration: 150 } }
                                }
                            }
                        }
                        Text {
                            text: root.musicTitle; font.pixelSize: 11; font.family: "SF Pro Display"
                            color: "white"; elide: Text.ElideRight; maximumLineCount: 1
                            Layout.maximumWidth: 160
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: musicPillBg.color = Qt.rgba(1,1,1,0.08)
                        onExited:  musicPillBg.color = Qt.rgba(1,1,1,0.0)
                        onClicked: {
                            if (root._musicActualVisible) root.requestCloseMusic()
                            else root.musicPopupVisible = true
                        }
                    }
                }

                // System tray
                Item {
                    implicitWidth: SystemTray.items.count > 0 ? SystemTray.items.count * 26 : 0
                    implicitHeight: 30
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8; layoutDirection: Qt.RightToLeft
                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                required property var modelData
                                width: 18; height: 18

                                property string rawIcon:    modelData ? (modelData.icon ?? "") : ""
                                property bool   isBareName: rawIcon.length > 0 && !rawIcon.includes("/") && !rawIcon.includes(":")

                                Image { id: imgSvg; anchors.fill: parent; fillMode: Image.PreserveAspectFit; opacity: 0.82; visible: status === Image.Ready
                                    source: (isBareName && root.iconTheme.length > 0 && root.homeDir.length > 0)
                                        ? "file://" + root.homeDir + "/.local/share/icons/" + root.iconTheme + "/scalable/apps/" + rawIcon + ".svg" : "" }
                                Image { id: imgSymbolic; anchors.fill: parent; fillMode: Image.PreserveAspectFit; opacity: 0.82; visible: imgSvg.status !== Image.Ready && status === Image.Ready
                                    source: (isBareName && imgSvg.status !== Image.Ready && root.iconTheme.length > 0 && root.homeDir.length > 0)
                                        ? "file://" + root.homeDir + "/.local/share/icons/" + root.iconTheme + "/symbolic/apps/" + rawIcon + "-symbolic.svg" : "" }
                                Image { id: imgPng48; anchors.fill: parent; fillMode: Image.PreserveAspectFit; opacity: 0.82
                                    visible: imgSvg.status !== Image.Ready && imgSymbolic.status !== Image.Ready && status === Image.Ready
                                    source: (isBareName && imgSvg.status !== Image.Ready && imgSymbolic.status !== Image.Ready && root.iconTheme.length > 0 && root.homeDir.length > 0)
                                        ? "file://" + root.homeDir + "/.local/share/icons/" + root.iconTheme + "/48x48/apps/" + rawIcon + ".png" : "" }
                                Image { id: imgPng32; anchors.fill: parent; fillMode: Image.PreserveAspectFit; opacity: 0.82
                                    property bool prevFailed: imgSvg.status !== Image.Ready && imgSymbolic.status !== Image.Ready && imgPng48.status !== Image.Ready
                                    visible: prevFailed && status === Image.Ready
                                    source: (isBareName && prevFailed && root.iconTheme.length > 0 && root.homeDir.length > 0)
                                        ? "file://" + root.homeDir + "/.local/share/icons/" + root.iconTheme + "/32x32/apps/" + rawIcon + ".png" : "" }
                                Image { id: imgQtTheme; anchors.fill: parent; fillMode: Image.PreserveAspectFit; opacity: 0.82
                                    property bool prevFailed: imgSvg.status !== Image.Ready && imgSymbolic.status !== Image.Ready && imgPng48.status !== Image.Ready && imgPng32.status !== Image.Ready
                                    visible: prevFailed && status === Image.Ready
                                    source: prevFailed ? (isBareName ? "image://icon/" + rawIcon : rawIcon) : "" }
                                Image { id: imgDirect; anchors.fill: parent; fillMode: Image.PreserveAspectFit; opacity: 0.82
                                    visible: !isBareName && status === Image.Ready; source: !isBareName ? rawIcon : "" }

                                property bool allFailed: imgSvg.status !== Image.Ready && imgSymbolic.status !== Image.Ready &&
                                                         imgPng48.status !== Image.Ready && imgPng32.status !== Image.Ready &&
                                                         imgQtTheme.status !== Image.Ready && imgDirect.status !== Image.Ready
                                Rectangle {
                                    anchors.fill: parent; radius: 4; visible: parent.allFailed
                                    color: {
                                        if (!modelData || !modelData.title) return Qt.rgba(0.3,0.3,0.4,0.7)
                                        var h = 5381
                                        for (var i = 0; i < modelData.title.length; i++)
                                            h = ((h << 5) + h) + modelData.title.charCodeAt(i)
                                        return Qt.hsla(((h >>> 0) % 360) / 360, 0.55, 0.42, 0.85)
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData && modelData.title) ? modelData.title.charAt(0).toUpperCase() : "?"
                                        font.family: "SF Pro Display"; font.pixelSize: 11; font.weight: Font.SemiBold; color: "white"
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (m) => {
                                        if (!modelData) return
                                        m.button === Qt.LeftButton ? modelData.activate(0,0) : modelData.secondaryActivate(0,0)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // ── Settings Popup ────────────────────────────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PanelWindow {
            id: settingsPopupWindow
            screen: panelWindow.screen; visible: false
            anchors.top:    root.barEdge !== "bottom"
            anchors.bottom: root.barEdge === "bottom"
            anchors.left:   true
            margins { top: root.barEdge !== "bottom" ? 66 : 0; bottom: root.barEdge === "bottom" ? 66 : 0; left: 12 }
            implicitWidth: 360
            implicitHeight: Math.min(settingsCol.implicitHeight + 32, panelWindow.screen ? panelWindow.screen.height * 0.80 : 800)
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            property bool _closing: false
            function closeSettings() {
                if (_closing || !visible) return
                _closing = true; settingsFadeOut.start(); settingsSlideOut.start()
            }
            onVisibleChanged: {
                if (visible) {
                    _closing = false; locationField.text = root.weatherLocation
                    settingsAnimItem.opacity = 0.0; settingsSlide.y = root.slideDir * root.slideDistance
                    settingsFadeIn.start(); settingsSlideIn.start()
                }
            }

            NumberAnimation { id: settingsFadeIn;  target: settingsAnimItem; property: "opacity"; from: 0.0; to: 1.0; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
            NumberAnimation { id: settingsSlideIn; target: settingsSlide;    property: "y";       to: 0;     duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
            NumberAnimation { id: settingsFadeOut;  target: settingsAnimItem; property: "opacity"; to: 0.0;   duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut
                onFinished: { settingsPopupWindow.visible = false; settingsPopupWindow._closing = false } }
            NumberAnimation { id: settingsSlideOut; target: settingsSlide;    property: "y"; to: root.slideDir * root.slideDistance; duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut }

            Item {
                id: settingsAnimItem; anchors.fill: parent; opacity: 0.0
                transform: Translate { id: settingsSlide; y: root.slideDir * root.slideDistance }

                Rectangle {
                    anchors.fill: parent; radius: root.panelRadius
                    color: Qt.rgba(0.06,0.07,0.10,0.3); border.color: Qt.rgba(1,1,1,0.09); border.width: 1
                    Rectangle { anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                        width: parent.width * 0.4; height: 1; color: Qt.rgba(1,1,1,0.15); radius: 1 }
                }

                Flickable {
                    anchors.fill: parent; anchors.margins: 16; contentHeight: settingsCol.implicitHeight; clip: true
                    ScrollBar.vertical: ScrollBar {
                        policy: parent.contentHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        width: 3; contentItem: Rectangle { radius: 1.5; color: Qt.rgba(1,1,1,0.22) }
                        background: Rectangle { color: "transparent" }
                    }
                    Column {
                        id: settingsCol; width: parent.width; spacing: 0

                        RowLayout {
                            width: parent.width; height: 36
                            RowLayout { spacing: 8
                                Text { text: "\uf013"; font.family: "Symbols Nerd Font"; font.pixelSize: 13; color: Qt.rgba(1,1,1,0.45) }
                                Text { text: "Bar Settings"; font.family: "SF Pro Display"; font.pixelSize: 13; font.weight: Font.SemiBold; color: "white" }
                            }
                            Item { Layout.fillWidth: true }
                            Item { implicitWidth: 22; implicitHeight: 22
                                Rectangle { id: settingsCloseBg; anchors.fill: parent; radius: 11; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                                Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: settingsCloseBg.color = Qt.rgba(1,1,1,0.10); onExited: settingsCloseBg.color = Qt.rgba(1,1,1,0.0); onClicked: settingsPopupWindow.closeSettings() }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
                        Item { width: 1; height: 14 }

                        Text { text: "WEATHER LOCATION"; font.family: "SF Pro Display"; font.pixelSize: 9; font.weight: Font.SemiBold; color: Qt.rgba(1,1,1,0.30); font.letterSpacing: 0.8 }
                        Item { width: 1; height: 6 }

                        RowLayout {
                            width: parent.width; spacing: 8
                            Rectangle {
                                Layout.fillWidth: true; height: 32; radius: root.pillRadius
                                color: Qt.rgba(1,1,1,0.06)
                                border.color: locationField.activeFocus ? Qt.rgba(0.42,0.68,1.0,0.60) : Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                TextInput {
                                    id: locationField
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 2 }
                                    verticalAlignment: TextInput.AlignVCenter; focus: true
                                    font.family: "SF Pro Display"; font.pixelSize: 12; color: "white"
                                    selectionColor: Qt.rgba(0.42,0.68,1.0,0.35); clip: true
                                    Component.onCompleted: text = root.weatherLocation
                                    onAccepted: applyLocationBtn.applyLocation()
                                }
                            }
                            Item {
                                id: applyLocationBtn
                                implicitWidth: applyLabel.implicitWidth + 20; implicitHeight: 32
                                function applyLocation() {
                                    var loc = locationField.text.trim(); if (loc.length === 0) return
                                    root.weatherLocation = loc; root.lastWeatherFetch = null; root.chartData = []
                                    root.weatherTemp = "--°C"; root.weatherIcon = "🌡️"
                                    root.currentTemp = "--°C"; root.currentDesc = "—"
                                    root.todayLow = "--°"; root.todayHigh = "--°"; root.currentEmoji = "🌡️"
                                    root._coordsResolved = false
                                    root.fetchWeatherFull(); root.saveSettings()
                                }
                                Rectangle { id: applyBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(0.42,0.68,1.0,0.22); border.color: Qt.rgba(0.42,0.68,1.0,0.35); border.width: 1; Behavior on color { ColorAnimation { duration: 120 } } }
                                Text { id: applyLabel; anchors.centerIn: parent; text: "Apply"; font.family: "SF Pro Display"; font.pixelSize: 11; color: Qt.rgba(0.72,0.88,1.0,0.90) }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: applyBg.color = Qt.rgba(0.42,0.68,1.0,0.35); onExited: applyBg.color = Qt.rgba(0.42,0.68,1.0,0.22); onClicked: applyLocationBtn.applyLocation() }
                            }
                        }

                        Item { width: 1; height: 4 }
                        Text { text: "City name or region — resolved via Open-Meteo geocoding"; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.22); wrapMode: Text.WordWrap; width: parent.width }
                        Item { width: 1; height: 18 }

                        Text { text: "BAR POSITION"; font.family: "SF Pro Display"; font.pixelSize: 9; font.weight: Font.SemiBold; color: Qt.rgba(1,1,1,0.30); font.letterSpacing: 0.8 }
                        Item { width: 1; height: 8 }

                        RowLayout {
                            width: parent.width; spacing: 8
                            Repeater {
                                model: [{ edge: "top", icon: "\uf077", label: "Top" }, { edge: "bottom", icon: "\uf078", label: "Bottom" }]
                                delegate: Item {
                                    required property var modelData
                                    Layout.fillWidth: true; height: 36
                                    Rectangle {
                                        anchors.fill: parent; radius: root.pillRadius
                                        color: root.barEdge === modelData.edge ? Qt.rgba(0.42,0.68,1.0,0.22) : edgeOptHov.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05)
                                        border.color: root.barEdge === modelData.edge ? Qt.rgba(0.42,0.68,1.0,0.3) : Qt.rgba(1,1,1,0.09); border.width: 1
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }
                                    RowLayout { anchors.centerIn: parent; spacing: 7
                                        Text { text: modelData.icon; font.family: "Symbols Nerd Font"; font.pixelSize: 10; color: root.barEdge === modelData.edge ? Qt.rgba(0.72,0.88,1.0,0.90) : Qt.rgba(1,1,1,0.40) }
                                        Text { text: modelData.label; font.family: "SF Pro Display"; font.pixelSize: 12; color: root.barEdge === modelData.edge ? "white" : Qt.rgba(1,1,1,0.45) }
                                    }
                                    MouseArea { id: edgeOptHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.barEdge = modelData.edge; root.saveSettings() } }
                                }
                            }
                        }

                        Item { width: 1; height: 18 }
                        Text { text: "ICON THEME"; font.family: "SF Pro Display"; font.pixelSize: 9; font.weight: Font.SemiBold; color: Qt.rgba(1,1,1,0.30); font.letterSpacing: 0.8 }
                        Item { width: 1; height: 6 }

                        Item {
                            width: parent.width; height: 28
                            Rectangle { anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.06); border.color: root.iconTheme.length > 0 ? Qt.rgba(0.42,0.68,1.0,0.35) : Qt.rgba(1,1,1,0.10); border.width: 1 }
                            Text { anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                text: root.iconTheme.length > 0 ? root.iconTheme : "System default"; font.family: "SF Pro Display"; font.pixelSize: 11; color: root.iconTheme.length > 0 ? "white" : Qt.rgba(1,1,1,0.35); elide: Text.ElideRight }
                        }
                        Item { width: 1; height: 6 }

                        Item {
                            width: parent.width
                            height: root.iconThemeList.length === 0 ? 28 : Math.min(root.iconThemeList.length * 34, 136)
                            clip: true
                            Text { anchors.centerIn: parent; visible: root.iconThemeList.length === 0; text: "No themes found in ~/.local/share/icons"; font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.22) }
                            ListView {
                                id: themeListView; anchors.fill: parent; visible: root.iconThemeList.length > 0; model: root.iconThemeList; spacing: 4; clip: true
                                ScrollBar.vertical: ScrollBar {
                                    policy: themeListView.contentHeight > themeListView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                    width: 3
                                    contentItem: Rectangle { radius: 1.5; color: Qt.rgba(1,1,1,0.25) }
                                    background: Rectangle { color: "transparent" }
                                }
                                delegate: Item {
                                    required property string modelData; required property int index
                                    width: themeListView.width; height: 30
                                    property bool isActive: root.iconTheme === modelData
                                    Rectangle { anchors.fill: parent; radius: root.pillRadius; color: isActive ? Qt.rgba(0.42,0.68,1.0,0.20) : themeRowHov.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent"; border.color: isActive ? Qt.rgba(0.42,0.68,1.0,0.3) : "transparent"; border.width: 1; Behavior on color { ColorAnimation { duration: 110 } } }
                                    RowLayout { anchors { fill: parent; leftMargin: 10; rightMargin: 10 } spacing: 8
                                        Text { Layout.fillWidth: true; text: modelData; font.family: "SF Pro Display"; font.pixelSize: 11; color: isActive ? "white" : Qt.rgba(1,1,1,0.65); elide: Text.ElideRight }
                                        Text { visible: isActive; text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 10; color: Qt.rgba(0.72,0.88,1.0,0.90) }
                                    }
                                    MouseArea { id: themeRowHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.applyIconTheme(modelData) }
                                }
                            }
                        }

                        Item { width: 1; height: 6 }
                        Item {
                            width: parent.width; height: 24; visible: root.iconTheme.length > 0
                            Rectangle { id: clearThemeBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.04); border.color: Qt.rgba(1,1,1,0.08); border.width: 1; Behavior on color { ColorAnimation { duration: 110 } } }
                            Text { anchors.centerIn: parent; text: "Use system default"; font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.35) }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: clearThemeBg.color = Qt.rgba(1,1,1,0.09); onExited: clearThemeBg.color = Qt.rgba(1,1,1,0.04); onClicked: root.applyIconTheme("") }
                        }
                        Item { width: 1; height: 4 }
                        Text { width: parent.width; text: "⚠  Restart Quickshell for icon changes to take full effect."; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1.0,0.75,0.30,0.3); wrapMode: Text.WordWrap }
                        Item { width: 1; height: 14 }
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
                        Item { width: 1; height: 10 }
                        Text { text: "mango-bar · Hyprland"; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.16) }
                        Item { width: 1; height: 4 }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // ── Calendar Popup ────────────────────────────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PanelWindow {
            id: calendarPopupWindow
            screen: panelWindow.screen; visible: false
            anchors.top:    root.barEdge !== "bottom"
            anchors.bottom: root.barEdge === "bottom"
            anchors.right:  true
            margins {
                top: root.barEdge !== "bottom" ? 66 : 0; bottom: root.barEdge === "bottom" ? 66 : 0
                right: { var w = panelWindow.screen ? panelWindow.screen.width : 1920; return Math.round((w - 280) / 2) }
            }
            implicitWidth: 280; implicitHeight: calendarContentCol.implicitHeight + 32
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.exclusiveZone: -1

            property bool _closing: false
            function closeCalendar() {
                if (_closing || !visible) return
                _closing = true; calendarFadeOut.start(); calendarSlideOut.start()
            }
            onVisibleChanged: {
                if (visible) {
                    _closing = false; calendarAnimItem.opacity = 0.0
                    calendarSlide.y = root.slideDir * root.slideDistance
                    calendarFadeIn.start(); calendarSlideIn.start()
                }
            }

            NumberAnimation { id: calendarFadeIn;  target: calendarAnimItem; property: "opacity"; from: 0.0; to: 1.0; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
            NumberAnimation { id: calendarSlideIn; target: calendarSlide;    property: "y";       to: 0;     duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
            NumberAnimation { id: calendarFadeOut;  target: calendarAnimItem; property: "opacity"; to: 0.0;   duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut
                onFinished: { calendarPopupWindow.visible = false; calendarPopupWindow._closing = false } }
            NumberAnimation { id: calendarSlideOut; target: calendarSlide;    property: "y"; to: root.slideDir * root.slideDistance; duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut }

            Item {
                id: calendarAnimItem; anchors.fill: parent; opacity: 0.0
                transform: Translate { id: calendarSlide; y: root.slideDir * root.slideDistance }

                Rectangle {
                    anchors.fill: parent; radius: root.panelRadius
                    color: Qt.rgba(0.06,0.07,0.10,0.3); border.color: Qt.rgba(1,1,1,0.09); border.width: 1
                    Rectangle { anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                        width: parent.width * 0.4; height: 1; color: Qt.rgba(1,1,1,0.15); radius: 1 }
                }

                Column {
                    id: calendarContentCol
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
                    spacing: 0

                    RowLayout {
                        width: parent.width; height: 36
                        Item { implicitWidth: 26; implicitHeight: 26
                            Rectangle { id: prevBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                            Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 16; color: Qt.rgba(1,1,1,0.55) }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: prevBg.color = Qt.rgba(1,1,1,0.09); onExited: prevBg.color = Qt.rgba(1,1,1,0.0)
                                onClicked: { root.calMonth--; if (root.calMonth < 0) { root.calMonth = 11; root.calYear-- } } }
                        }
                        Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.monthNames[root.calMonth] + " " + root.calYear; font.family: "SF Pro Display"; font.pixelSize: 13; font.weight: Font.SemiBold; color: "white" }
                        Item { implicitWidth: 26; implicitHeight: 26
                            Rectangle { id: nextBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                            Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 16; color: Qt.rgba(1,1,1,0.55) }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: nextBg.color = Qt.rgba(1,1,1,0.09); onExited: nextBg.color = Qt.rgba(1,1,1,0.0)
                                onClicked: { root.calMonth++; if (root.calMonth > 11) { root.calMonth = 0; root.calYear++ } } }
                        }
                        Item { implicitWidth: 22; implicitHeight: 22
                            Rectangle { id: calCloseBg; anchors.fill: parent; radius: 11; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                            Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: calCloseBg.color = Qt.rgba(1,1,1,0.10); onExited: calCloseBg.color = Qt.rgba(1,1,1,0.0); onClicked: calendarPopupWindow.closeCalendar() }
                        }
                    }

                    Item { width: 1; height: 6 }
                    Row { width: parent.width; spacing: 0
                        Repeater { model: root.dayNames
                            delegate: Item { width: Math.floor(calendarContentCol.width / 7); height: 24
                                Text { anchors.centerIn: parent; text: modelData; font.family: "SF Pro Display"; font.pixelSize: 10; font.weight: Font.Medium; color: index >= 5 ? Qt.rgba(1,1,1,0.28) : Qt.rgba(1,1,1,0.38) }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
                    Item { width: 1; height: 4 }

                    Item {
                        width: parent.width; height: Math.ceil(root.calendarCells().length / 7) * 34
                        Repeater {
                            model: root.calendarCells()
                            delegate: Item {
                                required property var modelData; required property int index
                                property int cellW: Math.floor(calendarContentCol.width / 7)
                                x: (index % 7) * cellW; y: Math.floor(index / 7) * 34; width: cellW; height: 34
                                Rectangle { anchors.centerIn: parent; width: 28; height: 28; radius: root.squircleRadius; color: modelData.isToday ? Qt.rgba(0.42,0.68,1.0,0.88) : "transparent"; Behavior on color { ColorAnimation { duration: 120 } } }
                                Text { anchors.centerIn: parent; text: modelData ? modelData.day.toString() : ""; font.family: "SF Pro Display"; font.pixelSize: 12; font.weight: (modelData && modelData.isToday) ? Font.SemiBold : Font.Normal; color: !modelData ? "transparent" : modelData.isToday ? "white" : modelData.isCurrentMonth ? Qt.rgba(1,1,1,0.82) : Qt.rgba(1,1,1,0.22) }
                            }
                        }
                    }

                    Item { width: 1; height: 8 }
                    Item {
                        width: parent.width; height: 28
                        Rectangle { id: todayBtnBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.08); border.width: 1; Behavior on color { ColorAnimation { duration: 110 } } }
                        Text { anchors.centerIn: parent; text: "Today"; font.family: "SF Pro Display"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.50) }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: todayBtnBg.color = Qt.rgba(1,1,1,0.12); onExited: todayBtnBg.color = Qt.rgba(1,1,1,0.06); onClicked: { root.calYear = new Date().getFullYear(); root.calMonth = new Date().getMonth() } }
                    }
                    Item { width: 1; height: 4 }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // ── Weather Popup ─────────────────────────────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PanelWindow {
            id: weatherPopupWindow
            screen: panelWindow.screen; visible: false
            anchors.top:    root.barEdge !== "bottom"
            anchors.bottom: root.barEdge === "bottom"
            anchors.right:  true
            margins { top: root.barEdge !== "bottom" ? 66 : 0; bottom: root.barEdge === "bottom" ? 66 : 0; right: 12 }
            implicitWidth: 360; implicitHeight: 310
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.exclusiveZone: -1

            property bool _closing: false
            function closeWeather() {
                if (_closing || !visible) return
                _closing = true; weatherFadeOut.start(); weatherSlideOut.start()
            }
            onVisibleChanged: {
                if (visible) {
                    _closing = false; weatherAnimItem.opacity = 0.0
                    weatherSlide.y = root.slideDir * root.slideDistance
                    weatherFadeIn.start(); weatherSlideIn.start()
                }
            }

            NumberAnimation { id: weatherFadeIn;  target: weatherAnimItem; property: "opacity"; from: 0.0; to: 1.0; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
            NumberAnimation { id: weatherSlideIn; target: weatherSlide;    property: "y";       to: 0;     duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
            NumberAnimation { id: weatherFadeOut;  target: weatherAnimItem; property: "opacity"; to: 0.0;   duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut
                onFinished: { weatherPopupWindow.visible = false; weatherPopupWindow._closing = false } }
            NumberAnimation { id: weatherSlideOut; target: weatherSlide;    property: "y"; to: root.slideDir * root.slideDistance; duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut }

            Item {
                id: weatherAnimItem; anchors.fill: parent; opacity: 0.0
                transform: Translate { id: weatherSlide; y: root.slideDir * root.slideDistance }

                Rectangle {
                    anchors.fill: parent; radius: root.panelRadius
                    color: Qt.rgba(0.06,0.07,0.10,0.5); border.color: Qt.rgba(1,1,1,0.09); border.width: 1
                    Rectangle { anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                        width: parent.width * 0.5; height: 1; color: Qt.rgba(1,1,1,0.15); radius: 1 }
                }

                Column { anchors { fill: parent; margins: 16 } spacing: 0
                    RowLayout {
                        width: parent.width; height: 48
                        RowLayout { spacing: 10
                            Text { text: root.currentEmoji; font.pixelSize: 34 }
                            Column { spacing: 2
                                Text { text: root.currentTemp; font.family: "SF Pro Display"; font.pixelSize: 24; font.weight: Font.Light; color: "white" }
                                Text { text: root.currentDesc; font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.45); elide: Text.ElideRight }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Column { spacing: 3
                            Text { text: root.weatherLocation; font.family: "SF Pro Display"; font.pixelSize: 12; font.weight: Font.SemiBold; color: Qt.rgba(1,1,1,0.55); anchors.right: parent.right; elide: Text.ElideRight }
                            Text { text: "↓ " + root.todayLow + "  ↑ " + root.todayHigh; font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.35); anchors.right: parent.right }
                            Item { width: 22; height: 22; anchors.right: parent.right
                                Rectangle { id: wxCloseBg; anchors.fill: parent; radius: 11; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                                Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.35) }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: wxCloseBg.color = Qt.rgba(1,1,1,0.10); onExited: wxCloseBg.color = Qt.rgba(1,1,1,0.0); onClicked: weatherPopupWindow.closeWeather() }
                            }
                        }
                    }

                    Item { width: parent.width; height: 8 }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
                    Item { width: parent.width; height: 10 }

                    Item { width: parent.width; height: 160; visible: root.chartData.length === 0
                        Column { anchors.centerIn: parent; spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.weatherLoading ? "⏳" : "⚠️"; font.pixelSize: 24 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.weatherLoading ? "Fetching forecast…" : "Tap Refresh to retry"; font.family: "SF Pro Display"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.30) }
                        }
                    }

                    Item {
                        id: chartContainer; width: parent.width; height: 160; visible: root.chartData.length > 0; clip: false
                        Canvas {
                            id: tempCurveCanvas; anchors.fill: parent
                            readonly property int curveTop: 44; readonly property int curveBot: 116
                            property int slotW: root.chartData.length > 0 ? Math.floor(chartContainer.width / root.chartData.length) : 40
                            onSlotWChanged: requestPaint()
                            Connections { target: root; function onChartDataChanged() { if (root.chartData.length > 0) tempCurveCanvas.requestPaint() } }
                            Component.onCompleted: Qt.callLater(requestPaint)
                            onPaint: {
                                var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                                var data = root.chartData; if (data.length < 2) return
                                var iW = slotW, cTop = curveTop, cBot = curveBot, cH = cBot - cTop
                                var pts = []
                                for (var i = 0; i < data.length; i++) pts.push({ x: i * iW + iW / 2, y: cTop + data[i].normY * cH })
                                ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y)
                                for (var j = 1; j < pts.length; j++) { var mx = (pts[j-1].x + pts[j].x) / 2; ctx.bezierCurveTo(mx, pts[j-1].y, mx, pts[j].y, pts[j].x, pts[j].y) }
                                ctx.lineTo(pts[pts.length-1].x, cBot+20); ctx.lineTo(pts[0].x, cBot+20); ctx.closePath()
                                var grad = ctx.createLinearGradient(0, cTop, 0, cBot+20); grad.addColorStop(0.0, "rgba(110,195,255,0.30)"); grad.addColorStop(1.0, "rgba(110,195,255,0.0)")
                                ctx.fillStyle = grad; ctx.fill()
                                ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y)
                                for (var k = 1; k < pts.length; k++) { var mx2 = (pts[k-1].x + pts[k].x) / 2; ctx.bezierCurveTo(mx2, pts[k-1].y, mx2, pts[k].y, pts[k].x, pts[k].y) }
                                ctx.strokeStyle = "rgba(130,210,255,0.90)"; ctx.lineWidth = 1.8; ctx.stroke()
                                for (var m = 0; m < pts.length; m++) {
                                    var isNow = data[m].label === "Now"
                                    ctx.beginPath(); ctx.arc(pts[m].x, pts[m].y, isNow ? 4 : 2.5, 0, Math.PI*2)
                                    ctx.fillStyle = isNow ? "rgba(255,255,255,0.5)" : "rgba(160,220,255,0.5)"; ctx.fill()
                                    if (isNow) { ctx.beginPath(); ctx.arc(pts[m].x, pts[m].y, 7, 0, Math.PI*2); ctx.strokeStyle = "rgba(255,255,255,0.22)"; ctx.lineWidth = 1.5; ctx.stroke() }
                                }
                            }
                        }
                        Row { anchors.fill: parent
                            Repeater { model: root.chartData
                                delegate: Item {
                                    required property var modelData; required property int index
                                    width: tempCurveCanvas.slotW; height: chartContainer.height
                                    property real dotY: tempCurveCanvas.curveTop + modelData.normY * (tempCurveCanvas.curveBot - tempCurveCanvas.curveTop)
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 2; text: modelData ? modelData.label : ""; font.family: "SF Pro Display"; font.pixelSize: 10; font.weight: (modelData && modelData.label === "Now") ? Font.SemiBold : Font.Normal; color: (modelData && modelData.label === "Now") ? "white" : Qt.rgba(1,1,1,0.38) }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 18; text: modelData ? modelData.emoji : ""; font.pixelSize: 18 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: dotY - 16; text: modelData ? modelData.tempLabel : ""; font.family: "SF Pro Display"; font.pixelSize: 10; font.weight: Font.Medium; color: (modelData && modelData.label === "Now") ? "white" : Qt.rgba(1,1,1,0.70) }
                                }
                            }
                        }
                    }

                    Item { width: parent.width; height: 10 }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
                    Item { width: parent.width; height: 8 }
                    RowLayout { width: parent.width
                        Text { text: "open-meteo.com · " + root.weatherLocation; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.18) }
                        Item { Layout.fillWidth: true }
                        Item {
                            implicitWidth: refreshLabel.implicitWidth + 22; implicitHeight: 22
                            Rectangle { id: refreshBg; anchors.fill: parent; radius: root.pillRadius; color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.08); border.width: 1; Behavior on color { ColorAnimation { duration: 110 } } }
                            RowLayout { anchors.centerIn: parent; spacing: 5
                                Text { text: "\uf021"; font.family: "Symbols Nerd Font"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.45)
                                    RotationAnimation on rotation { id: spinAnim; running: false; from: 0; to: 360; duration: 600; loops: 1; easing.type: Easing.OutCubic } }
                                Text { id: refreshLabel; text: "Refresh"; font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.45) }
                            }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: refreshBg.color = Qt.rgba(1,1,1,0.13); onExited: refreshBg.color = Qt.rgba(1,1,1,0.07); onClicked: { spinAnim.running = true; root.lastWeatherFetch = null; root.fetchWeatherFull() } }
                        }
                    }
                }
            }
        }

    } // PanelWindow (panelWindow)
} // Variants
