import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: musicPopupWindow
        property var modelData
        screen: modelData
        visible: root._musicActualVisible
        anchors.top:    root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"
        anchors.right:  true
        margins { top: root.barEdge !== "bottom" ? 66 : 0; bottom: root.barEdge === "bottom" ? 66 : 0; right: 12 }
        implicitWidth: 340; implicitHeight: musicPopupCol.implicitHeight + 32
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.exclusiveZone: -1

        property bool _closing: false
        function closeMusic() {
            if (_closing || !visible) return
            _closing = true
            root.musicPopupVisible = false
            musicFadeOut.start(); musicSlideOut.start()
        }

        // Pill button lives in a different Variants scope — it signals via root flag
        Connections {
            target: root
            function on_musicCloseRequestedChanged() {
                if (root._musicCloseRequested) {
                    root._musicCloseRequested = false
                    musicPopupWindow.closeMusic()
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                _closing = false
                musicAnimItem.opacity = 0.0
                musicSlide.y = root.slideDir * root.slideDistance
                musicFadeIn.start(); musicSlideIn.start()
            }
        }

        NumberAnimation { id: musicFadeIn;  target: musicAnimItem; property: "opacity"; from: 0.0; to: 1.0; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
        NumberAnimation { id: musicSlideIn; target: musicSlide;    property: "y";       to: 0;               duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierIn }
        NumberAnimation { id: musicFadeOut;  target: musicAnimItem; property: "opacity"; to: 0.0;             duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut
            onFinished: { root._musicActualVisible = false; musicPopupWindow._closing = false } }
        NumberAnimation { id: musicSlideOut; target: musicSlide;    property: "y"; to: root.slideDir * root.slideDistance; duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: root.popupBezierOut }

        Item {
            id: musicAnimItem
            anchors.fill: parent; opacity: 0.0
            transform: Translate { id: musicSlide; y: root.slideDir * root.slideDistance }

            Rectangle {
                anchors.fill: parent; radius: root.panelRadius
                color: Qt.rgba(0.06,0.07,0.10,0.55); border.color: Qt.rgba(1,1,1,0.09); border.width: 1
                Rectangle { anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                    width: parent.width * 0.5; height: 1; color: Qt.rgba(1,1,1,0.15); radius: 1 }
            }

            Column {
                id: musicPopupCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
                spacing: 0

                // ── Header ─────────────────────────────────────────────────
                RowLayout {
                    width: parent.width; height: 30
                    RowLayout { spacing: 7
                        Text { text: "\uf001"; font.family: "Symbols Nerd Font"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.40) }
                        Text { text: "Now Playing"; font.family: "SF Pro Display"; font.pixelSize: 12; font.weight: Font.SemiBold; color: "white" }
                        Rectangle {
                            visible: root.musicPlayer.length > 0; radius: root.pillRadius; height: 16
                            implicitWidth: playerBadgeText.implicitWidth + 12
                            color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.09); border.width: 1
                            Text { id: playerBadgeText; anchors.centerIn: parent; text: root.musicPlayer; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Item { implicitWidth: 22; implicitHeight: 22
                        Rectangle { id: musicCloseBg; anchors.fill: parent; radius: 11; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 100 } } }
                        Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: musicCloseBg.color = Qt.rgba(1,1,1,0.10); onExited: musicCloseBg.color = Qt.rgba(1,1,1,0.0); onClicked: musicPopupWindow.closeMusic() }
                    }
                }

                Item { width: 1; height: 12 }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
                Item { width: 1; height: 12 }

                // ── Album art + track info ──────────────────────────────────
                RowLayout { width: parent.width; height: 80; spacing: 14
                    Item { width: 80; height: 80
                        Rectangle { anchors.centerIn: parent; width: 84; height: 84; radius: root.squircleRadius + 2; color: Qt.rgba(0.15,0.20,0.30,0.6); opacity: albumArtImage.status === Image.Ready ? 0.7 : 0; Behavior on opacity { NumberAnimation { duration: 300 } } }
                        Rectangle { anchors.fill: parent; radius: root.squircleRadius; color: Qt.rgba(0.10,0.12,0.18,1.0); clip: true
                            Image { id: albumArtImage; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: root.musicArtUrl; smooth: true; opacity: status === Image.Ready ? 1.0 : 0.0; Behavior on opacity { NumberAnimation { duration: 200 } } }
                            Text { anchors.centerIn: parent; visible: albumArtImage.status !== Image.Ready; text: "\uf001"; font.family: "Symbols Nerd Font"; font.pixelSize: 28; color: Qt.rgba(1,1,1,0.18) }
                        }
                    }
                    Column { Layout.fillWidth: true; spacing: 5
                        Text { width: parent.width; text: root.musicTitle;  font.family: "SF Pro Display"; font.pixelSize: 14; font.weight: Font.SemiBold; color: "white";               elide: Text.ElideRight; maximumLineCount: 1 }
                        Text { width: parent.width; text: root.musicArtist; font.family: "SF Pro Display"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.55);  elide: Text.ElideRight; maximumLineCount: 1 }
                        Text { width: parent.width; visible: root.musicAlbum.length > 0; text: root.musicAlbum; font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.28); elide: Text.ElideRight; maximumLineCount: 1 }
                    }
                }

                // ── Progress bar ────────────────────────────────────────────
                Item { width: 1; height: 16 }
                Item { width: parent.width; height: 3
                    Rectangle { anchors.fill: parent; radius: 1.5; color: Qt.rgba(1,1,1,0.10) }
                    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width * root.musicProgress; radius: 1.5
                        color: Qt.rgba(0.72,0.88,1.0,0.85)
                        Behavior on width { NumberAnimation { duration: 950; easing.type: Easing.Linear } }
                    }
                }
                Item { width: 1; height: 4 }
                RowLayout { width: parent.width
                    Text { text: { var s = Math.floor(root.musicPosition/1000000); return Math.floor(s/60).toString().padStart(2,"0") + ":" + (s%60).toString().padStart(2,"0") }
                        font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.28) }
                    Item { Layout.fillWidth: true }
                    Text { text: { var s = Math.floor(root.musicLength/1000000); return s > 0 ? Math.floor(s/60).toString().padStart(2,"0") + ":" + (s%60).toString().padStart(2,"0") : "--:--" }
                        font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.28) }
                }

                // ── Transport controls ──────────────────────────────────────
                Item { width: 1; height: 14 }
                RowLayout { width: parent.width; spacing: 0
                    Item { Layout.fillWidth: true }
                    Item { implicitWidth: 40; implicitHeight: 40
                        Rectangle { id: prevCtrlBg; anchors.fill: parent; radius: 20; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 120 } } }
                        Text { anchors.centerIn: parent; text: "\uf048"; font.family: "Symbols Nerd Font"; font.pixelSize: 15; color: Qt.rgba(1,1,1,0.70) }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: prevCtrlBg.color = Qt.rgba(1,1,1,0.09); onExited: prevCtrlBg.color = Qt.rgba(1,1,1,0.0); onClicked: root.musicPrevTrack() }
                    }
                    Item { implicitWidth: 8 }
                    Item { implicitWidth: 56; implicitHeight: 40
                        Rectangle { id: playPauseBg; anchors.fill: parent; radius: root.squircleRadius; color: Qt.rgba(0.42,0.68,1.0,0.22); border.color: Qt.rgba(0.42,0.68,1.0,0.30); border.width: 1; Behavior on color { ColorAnimation { duration: 120 } } }
                        Text { anchors.centerIn: parent; text: root.musicStatus === "Playing" ? "\uf04c" : "\uf04b"; font.family: "Symbols Nerd Font"; font.pixelSize: 18; color: Qt.rgba(0.72,0.88,1.0,0.95) }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: playPauseBg.color = Qt.rgba(0.42,0.68,1.0,0.38); onExited: playPauseBg.color = Qt.rgba(0.42,0.68,1.0,0.22); onClicked: root.musicTogglePlay() }
                    }
                    Item { implicitWidth: 8 }
                    Item { implicitWidth: 40; implicitHeight: 40
                        Rectangle { id: nextCtrlBg; anchors.fill: parent; radius: 20; color: Qt.rgba(1,1,1,0.0); Behavior on color { ColorAnimation { duration: 120 } } }
                        Text { anchors.centerIn: parent; text: "\uf051"; font.family: "Symbols Nerd Font"; font.pixelSize: 15; color: Qt.rgba(1,1,1,0.70) }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: nextCtrlBg.color = Qt.rgba(1,1,1,0.09); onExited: nextCtrlBg.color = Qt.rgba(1,1,1,0.0); onClicked: root.musicNextTrack() }
                    }
                    Item { Layout.fillWidth: true }
                }

                // ── Cava visualiser ─────────────────────────────────────────
                Item { width: 1; height: 14 }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
                Item { width: 1; height: 12 }

                Item { width: parent.width; height: 64
                    Canvas {
                        id: cavaCanvas; anchors.fill: parent
                        Connections {
                            target: root
                            function onCavaHeightsChanged() { cavaCanvas.requestPaint() }
                            function onMusicStatusChanged() { cavaCanvas.requestPaint() }
                        }
                        Component.onCompleted: Qt.callLater(requestPaint)
                        onPaint: {
                            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                            var bars = root.cavaHeights, n = bars.length, bW = 7
                            var totalGap = width - n * bW, gap = totalGap / (n + 1)
                            var maxH = height - 2, playing = root.musicStatus === "Playing"
                            for (var i = 0; i < n; i++) {
                                var h = Math.max(3, bars[i] * maxH), x = gap + i * (bW + gap), y = height - h
                                var g = ctx.createLinearGradient(x, y, x, height)
                                if (playing) { g.addColorStop(0.0,"rgba(190,230,255,0.95)"); g.addColorStop(0.45,"rgba(100,180,255,0.65)"); g.addColorStop(1.0,"rgba(60,130,220,0.25)") }
                                else         { g.addColorStop(0.0,"rgba(100,110,130,0.35)"); g.addColorStop(1.0,"rgba(70,80,100,0.12)") }
                                ctx.fillStyle = g
                                var r = Math.min(bW/2, h/2, 3.5)
                                ctx.beginPath(); ctx.moveTo(x+r,y); ctx.lineTo(x+bW-r,y); ctx.quadraticCurveTo(x+bW,y,x+bW,y+r)
                                ctx.lineTo(x+bW,height); ctx.lineTo(x,height); ctx.lineTo(x,y+r); ctx.quadraticCurveTo(x,y,x+r,y)
                                ctx.closePath(); ctx.fill()
                            }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: root.musicStatus !== "Playing"
                        text: root.musicStatus === "Paused" ? "⏸  paused" : "—  no signal"
                        font.family: "SF Pro Display"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.18) }
                }

                Item { width: 1; height: 6 }
                Text { text: root.cavaAvailable ? "cava · live audio" : "cava · simulated"; font.family: "SF Pro Display"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.16) }
                Item { width: 1; height: 4 }
            }
        }
    }
}
