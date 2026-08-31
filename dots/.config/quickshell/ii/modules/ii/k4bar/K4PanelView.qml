import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root

    required property var plugin

    opacity: 0
    Component.onCompleted: fadeIn.start()

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 14
        anchors.bottomMargin: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 8

            K4PanelButton {
                visible: root.plugin.tab !== "controls"
                glyph: K4Theme.ico.back
                glyphSize: 15
                onActivated: {
                    K4Wifi.cancelPassword()
                    root.plugin.tab = "controls"
                }
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.plugin.tab === "notifications" ? "Notifications"
                    : root.plugin.tab === "wifi" ? "Wi-Fi"
                    : root.plugin.tab === "bluetooth" ? "Bluetooth"
                    : root.plugin.tab === "sonido" ? "Sound"
                    : "Control Center"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                visible: root.plugin.tab === "notifications" && K4Notifications.history.length > 0
                Layout.preferredWidth: clearLabel.implicitWidth + 34
                Layout.preferredHeight: 24
                radius: 12
                color: clearHover.hovered ? K4Theme.red : K4Theme.surfaceHi

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: K4Theme.ico.clearAll
                        color: K4Theme.muted
                        font.family: K4Theme.iconFont
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: clearLabel
                        text: "Clear all"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: clearHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: K4Notifications.clear()
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 5
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: K4Workspaces.list
                    delegate: Rectangle {
                        id: workspaceDot
                        required property var modelData
                        width: modelData.focused ? 24 : 8
                        height: 8
                        radius: 4
                        color: modelData.focused ? K4Theme.ink : K4Theme.surfaceHi

                        Behavior on width {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: workspaceDot.modelData.activate()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Qt.formatDateTime(K4Clock.date, "HH:mm")
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 13
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            K4PanelButton {
                glyph: K4Notifications.count > 0 ? K4Theme.ico.bell : K4Theme.ico.bellOutline
                glyphSize: 14
                active: root.plugin.tab === "notifications"
                onActivated: {
                    root.plugin.tab = root.plugin.tab === "notifications" ? "controls" : "notifications"
                    if (root.plugin.tab === "notifications")
                        K4Notifications.markRead()
                }
                Layout.alignment: Qt.AlignVCenter
            }

            K4PanelButton {
                glyph: K4Theme.ico.chevronUp
                glyphSize: 15
                onActivated: root.plugin.close()
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                visible: root.plugin.tab === "controls"

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78
                    spacing: 10

                    K4PanelTile {
                        id: wifiTile
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onActivated: root.plugin.openTab("wifi")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                radius: 15
                                color: K4Wifi.enabled ? K4Theme.blue : K4Theme.surfaceHi

                                Behavior on color { ColorAnimation { duration: 180 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: K4Wifi.enabled ? K4Theme.ico.wifi : K4Theme.ico.wifiOff
                                    color: K4Theme.ink
                                    font.family: K4Theme.iconFont
                                    font.pixelSize: 15
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: K4Wifi.toggle()
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: "Wi-Fi"
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: K4Wifi.enabled
                                        ? (K4Wifi.name.length > 0 ? K4Wifi.name : K4Wifi.statusText)
                                        : "Off"
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                            }

                            Text {
                                text: K4Theme.ico.forward
                                color: wifiTile.hovered ? K4Theme.ink : K4Theme.dim
                                font.family: K4Theme.iconFont
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    K4PanelTile {
                        id: bluetoothTile
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onActivated: root.plugin.openTab("bluetooth")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                radius: 15
                                color: K4Bluetooth.enabled ? K4Theme.blue : K4Theme.surfaceHi

                                Behavior on color { ColorAnimation { duration: 180 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: K4Bluetooth.enabled
                                        ? K4Theme.ico.bluetooth : K4Theme.ico.bluetoothOff
                                    color: K4Theme.ink
                                    font.family: K4Theme.iconFont
                                    font.pixelSize: 15
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: K4Bluetooth.available
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: K4Bluetooth.toggle()
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: "Bluetooth"
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: !K4Bluetooth.available ? "No adapter"
                                        : K4Bluetooth.enabled ? "On" : "Off"
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                            }

                            Text {
                                text: K4Theme.ico.forward
                                color: bluetoothTile.hovered ? K4Theme.ink : K4Theme.dim
                                font.family: K4Theme.iconFont
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    K4PanelTile {
                        id: soundTile
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onActivated: root.plugin.openTab("sonido")

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            anchors.topMargin: 10
                            anchors.bottomMargin: 9
                            spacing: 7

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 7

                                Text {
                                    text: "Sound"
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: K4AudioDevices.nameFor(K4AudioDevices.activeOutput)
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    text: K4Theme.ico.forward
                                    color: soundTile.hovered ? K4Theme.ink : K4Theme.dim
                                    font.family: K4Theme.iconFont
                                    font.pixelSize: 13
                                    renderType: Text.NativeRendering
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26

                                Rectangle {
                                    id: volumeTrack
                                    anchors.fill: parent
                                    radius: 13
                                    color: K4Theme.surfaceHi
                                    clip: true

                                    Rectangle {
                                        width: volumeTrack.width * Math.max(0, Math.min(1, K4Audio.volume / 100))
                                        height: parent.height
                                        radius: parent.radius
                                        color: K4Audio.muted ? K4Theme.dim : K4Theme.ink
                                        Behavior on width {
                                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                        }
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: K4Audio.muted ? K4Theme.ico.volOff : K4Theme.ico.volMed
                                        color: K4Audio.volume > 12 && !K4Audio.muted
                                            ? K4Theme.islandBg : K4Theme.muted
                                        font.family: K4Theme.iconFont
                                        font.pixelSize: 12
                                        renderType: Text.NativeRendering
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    function setAt(x) { K4Audio.setVolume(x / Math.max(1, width) * 100) }
                                    onPressed: function(event) { setAt(event.x) }
                                    onPositionChanged: function(event) {
                                        if (pressed)
                                            setAt(event.x)
                                    }
                                }
                            }
                        }
                    }
                }

                K4PanelTile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    interactive: false

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 11

                        ClippingRectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 7
                            color: K4Theme.surfaceHi

                            Image {
                                id: mediaCover
                                anchors.fill: parent
                                source: K4Media.coverFor(K4Media.activePlayer)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !mediaCover.visible
                                text: K4Theme.ico.music
                                color: K4Theme.muted
                                font.family: K4Theme.iconFont
                                font.pixelSize: 16
                                renderType: Text.NativeRendering
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: K4Media.hasPlayer && K4Media.activePlayer.trackTitle.length > 0
                                    ? K4Media.activePlayer.trackTitle : "Nothing playing"
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                            Text {
                                Layout.fillWidth: true
                                text: K4Media.hasPlayer ? K4Media.activePlayer.trackArtist : ""
                                color: K4Theme.muted
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                        }

                        K4PanelButton {
                            glyph: K4Theme.ico.prev
                            glyphSize: 16
                            enabledAction: K4Media.hasPlayer && K4Media.activePlayer.canGoPrevious
                            onActivated: K4Media.previous()
                        }
                        K4PanelButton {
                            glyph: K4Media.isPlaying ? K4Theme.ico.pause : K4Theme.ico.play
                            glyphSize: 20
                            enabledAction: K4Media.hasPlayer && K4Media.activePlayer.canTogglePlaying
                            onActivated: K4Media.togglePlaying()
                        }
                        K4PanelButton {
                            glyph: K4Theme.ico.next
                            glyphSize: 16
                            enabledAction: K4Media.hasPlayer && K4Media.activePlayer.canGoNext
                            onActivated: K4Media.next()
                        }
                    }
                }

                K4ShortcutStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    controller: root.plugin.controller
                    panel: root.plugin
                }
            }

            K4PanelWifiView {
                anchors.fill: parent
                visible: root.plugin.tab === "wifi"
            }

            K4PanelBluetoothView {
                anchors.fill: parent
                visible: root.plugin.tab === "bluetooth"
            }

            K4PanelAudioView {
                anchors.fill: parent
                visible: root.plugin.tab === "sonido"
            }

            K4PanelNotificationsView {
                anchors.fill: parent
                visible: root.plugin.tab === "notifications"
            }
        }
    }
}
