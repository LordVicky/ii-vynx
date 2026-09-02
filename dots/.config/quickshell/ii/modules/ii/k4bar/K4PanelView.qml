import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var plugin

    readonly property var captureTarget: root.target("capture")
    readonly property var connectedBluetooth: {
        const devices = K4Bluetooth.devices
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].connected)
                return devices[i]
        }
        return null
    }
    readonly property bool recording: captureTarget?.recording ?? false

    function target(name) {
        return root.plugin.controller?.plugin(name) ?? null
    }

    function launch(name) {
        const destination = target(name)
        if (!destination || !destination.enabled)
            return

        root.plugin.close()
        if (typeof destination.openApplication === "function"
                && destination.openApplication())
            return
        if (typeof destination.toggle === "function")
            destination.toggle()
        else if (typeof destination.open === "function")
            destination.open()
    }

    function openRecord() {
        const capture = captureTarget
        if (!capture || !capture.enabled)
            return

        if (capture.recording) {
            capture.stopRecording()
            return
        }

        root.plugin.close()
        if (typeof capture.openRecord === "function")
            capture.openRecord()
        else
            capture.openApplication()
    }

    function glyphFor(name, fallback) {
        const destination = target(name)
        return destination?.applicationGlyph?.length > 0
            ? destination.applicationGlyph : fallback
    }

    function weatherSubtitle() {
        if (!K4Weather.ready)
            return K4Weather.place.length > 0 ? K4Weather.place : "Open forecast"
        const temp = String(K4Weather.current.temp || "")
        const description = String(K4Weather.current.wDesc || "")
        return [temp, description].filter(value => value.length > 0).join(" · ")
    }

    function bluetoothSubtitle() {
        if (!K4Bluetooth.available)
            return "No adapter"
        if (!K4Bluetooth.enabled)
            return "Off"
        if (connectedBluetooth)
            return connectedBluetooth.name?.length > 0
                ? connectedBluetooth.name : connectedBluetooth.address
        return "On"
    }

    function goHome() {
        K4Wifi.cancelPassword()
        root.plugin.tab = "controls"
    }

    opacity: 0
    Component.onCompleted: {
        K4Media.watchPosition()
        fadeIn.start()
    }
    Component.onDestruction: K4Media.unwatchPosition()

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    component PanelCard: Rectangle {
        radius: 18
        color: K4Theme.panelSurface
        border.width: 1
        border.color: K4Theme.panelLine
    }

    component ToolTile: Rectangle {
        id: tile
        required property string title
        required property string glyph
        property bool enabledAction: true
        property bool danger: false
        signal activated()

        radius: 13
        color: danger
            ? Qt.rgba(1, 0.38, 0.42, hover.hovered ? 0.16 : 0.10)
            : hover.hovered ? K4Theme.panelSurfaceHot : K4Theme.panelSurfaceHi
        border.width: 1
        border.color: danger
            ? Qt.rgba(1, 0.38, 0.42, 0.18)
            : hover.hovered ? Qt.rgba(1, 1, 1, 0.075) : "transparent"
        opacity: enabledAction ? 1 : 0.38

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Column {
            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.glyph
                color: tile.danger ? "#ff9ba2" : K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 16
                renderType: Text.NativeRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, tile.width - 12)
                text: tile.title
                color: tile.danger ? "#ff9ba2" : K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: tile.title === "Stop Recording" ? 7 : 8
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        HoverHandler { id: hover; enabled: tile.enabledAction }
        TapHandler {
            enabled: tile.enabledAction
            cursorShape: Qt.PointingHandCursor
            onTapped: tile.activated()
        }
    }

    component DesktopTile: Rectangle {
        id: tile
        required property string title
        required property string subtitle
        required property string glyph
        property bool enabledAction: true
        signal activated()

        radius: 13
        color: hover.hovered && enabledAction
            ? K4Theme.panelSurfaceHot : K4Theme.panelSurfaceHi
        opacity: enabledAction ? 1 : 0.38

        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 9
                color: K4Theme.panelSurfaceHot

                Text {
                    anchors.centerIn: parent
                    text: tile.glyph
                    color: K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }
            }

            ColumnLayout {
                Layout.minimumWidth: 0
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: tile.title
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: tile.subtitle
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 7
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }

        HoverHandler { id: hover; enabled: tile.enabledAction }
        TapHandler {
            enabled: tile.enabledAction
            cursorShape: Qt.PointingHandCursor
            onTapped: tile.activated()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 16
        spacing: 11

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 9

            K4PanelButton {
                visible: root.plugin.tab !== "controls"
                glyph: K4Theme.ico.back
                glyphSize: 14
                activeColor: K4Theme.panelSurfaceHi
                onActivated: root.goHome()
            }

            Rectangle {
                visible: root.plugin.tab === "controls"
                Layout.preferredWidth: 25
                Layout.preferredHeight: 25
                radius: 9
                color: K4Theme.panelSurfaceHi

                Text {
                    anchors.centerIn: parent
                    text: "⌘"
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
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
                Layout.preferredWidth: clearLabel.implicitWidth + 30
                Layout.preferredHeight: 24
                radius: 12
                color: clearHover.hovered ? K4Theme.red : K4Theme.panelSurfaceHi

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: K4Theme.ico.clearAll
                        color: K4Theme.muted
                        font.family: K4Theme.iconFont
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    Text {
                        id: clearLabel
                        text: "Clear all"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
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
                        width: modelData.focused ? 24 : 7
                        height: 7
                        radius: 4
                        color: modelData.focused ? K4Theme.ink : K4Theme.panelSurfaceHot

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
                font.pixelSize: 12
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                K4PanelButton {
                    anchors.fill: parent
                    glyph: K4Notifications.count > 0
                        ? K4Theme.ico.bell : K4Theme.ico.bellOutline
                    glyphSize: 13
                    active: root.plugin.tab === "notifications"
                    activeColor: K4Theme.panelSurfaceHot
                    onActivated: {
                        root.plugin.tab = root.plugin.tab === "notifications"
                            ? "controls" : "notifications"
                        if (root.plugin.tab === "notifications")
                            K4Notifications.markRead()
                    }
                }

                Rectangle {
                    visible: K4Notifications.count > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -2
                    anchors.topMargin: -3
                    width: Math.max(14, badgeText.implicitWidth + 6)
                    height: 14
                    radius: 7
                    color: K4Theme.panelBlue
                    border.width: 2
                    border.color: K4Theme.islandBg

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: K4Notifications.count
                        color: "#07101a"
                        font.family: K4Theme.uiFont
                        font.pixelSize: 7
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                }
            }

            K4PanelButton {
                glyph: K4Theme.ico.chevronUp
                glyphSize: 14
                activeColor: K4Theme.panelSurfaceHi
                onActivated: root.plugin.close()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                id: homeColumns
                anchors.fill: parent
                spacing: 10
                visible: root.plugin.tab === "controls"

                readonly property int leftWidth: Math.round((width - spacing) * 0.54)

                ColumnLayout {
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: homeColumns.leftWidth
                    Layout.maximumWidth: homeColumns.leftWidth
                    Layout.fillHeight: true
                    spacing: 10

                    PanelCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            K4PanelTile {
                                id: wifiTile
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                baseColor: K4Theme.panelSurfaceHi
                                hoverColor: K4Theme.panelSurfaceHot
                                cornerRadius: 14
                                onActivated: root.plugin.openTab("wifi")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: K4Wifi.enabled
                                            ? K4Theme.panelBlue : K4Theme.panelSurfaceHot

                                        Behavior on color { ColorAnimation { duration: 160 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: K4Wifi.enabled
                                                ? K4Theme.ico.wifi : K4Theme.ico.wifiOff
                                            color: K4Wifi.enabled ? "#07111e" : K4Theme.muted
                                            font.family: K4Theme.iconFont
                                            font.pixelSize: 14
                                            renderType: Text.NativeRendering
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: K4Wifi.toggle()
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.minimumWidth: 0
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "Wi-Fi"
                                            color: K4Theme.ink
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: K4Wifi.enabled
                                                ? (K4Wifi.name.length > 0
                                                    ? K4Wifi.name : K4Wifi.statusText)
                                                : "Off"
                                            color: K4Theme.muted
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 8
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
                                baseColor: K4Theme.panelSurfaceHi
                                hoverColor: K4Theme.panelSurfaceHot
                                cornerRadius: 14
                                onActivated: root.plugin.openTab("bluetooth")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: K4Bluetooth.enabled
                                            ? K4Theme.panelBlue : K4Theme.panelSurfaceHot

                                        Behavior on color { ColorAnimation { duration: 160 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: K4Bluetooth.enabled
                                                ? K4Theme.ico.bluetooth : K4Theme.ico.bluetoothOff
                                            color: K4Bluetooth.enabled ? "#07111e" : K4Theme.muted
                                            font.family: K4Theme.iconFont
                                            font.pixelSize: 14
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
                                        Layout.minimumWidth: 0
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "Bluetooth"
                                            color: K4Theme.ink
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.bluetoothSubtitle()
                                            color: K4Theme.muted
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 8
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
                        }
                    }

                    PanelCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 94

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 10
                            anchors.bottomMargin: 9
                            spacing: 7

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Sound"
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    Layout.minimumWidth: 0
                                    Layout.maximumWidth: 190
                                    text: K4AudioDevices.nameFor(K4AudioDevices.activeOutput)
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                spacing: 9

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: 14
                                    color: muteHover.hovered
                                        ? K4Theme.panelSurfaceHot : K4Theme.panelSurfaceHi

                                    Text {
                                        anchors.centerIn: parent
                                        text: K4Audio.muted
                                            ? K4Theme.ico.volOff : K4Theme.ico.volMed
                                        color: K4Theme.muted
                                        font.family: K4Theme.iconFont
                                        font.pixelSize: 12
                                        renderType: Text.NativeRendering
                                    }

                                    HoverHandler { id: muteHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: K4Audio.toggleMute()
                                    }
                                }

                                Item {
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20

                                    Rectangle {
                                        id: volumeTrack
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: "#29313a"

                                        Rectangle {
                                            width: volumeTrack.width
                                                * Math.max(0, Math.min(1, K4Audio.volume / 100))
                                            height: parent.height
                                            radius: parent.radius
                                            color: K4Theme.ink
                                        }

                                        Rectangle {
                                            x: Math.max(0, Math.min(parent.width - width,
                                                volumeTrack.width
                                                    * Math.max(0, Math.min(1, K4Audio.volume / 100))
                                                    - width / 2))
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: K4Theme.ink
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.topMargin: -4
                                        anchors.bottomMargin: -4
                                        cursorShape: Qt.PointingHandCursor
                                        function setAt(x) {
                                            K4Audio.setVolume(x / Math.max(1, width) * 100)
                                        }
                                        onPressed: function(event) { setAt(event.x) }
                                        onPositionChanged: function(event) {
                                            if (pressed)
                                                setAt(event.x)
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 34
                                    text: Math.round(K4Audio.volume) + "%"
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignRight
                                    renderType: Text.NativeRendering
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "Output"
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "•"
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    text: K4AudioDevices.nameFor(K4AudioDevices.activeOutput)
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: "Change device  " + K4Theme.ico.forward
                                    color: soundHover.hovered ? K4Theme.ink : K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering

                                    HoverHandler { id: soundHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: root.plugin.openTab("sonido")
                                    }
                                }
                            }
                        }
                    }

                    PanelCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GridLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            columns: 3
                            rows: 2
                            columnSpacing: 7
                            rowSpacing: 7

                            ToolTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: "Capture"
                                glyph: root.glyphFor("capture", String.fromCodePoint(0xF0379))
                                enabledAction: root.target("capture")?.enabled ?? false
                                onActivated: root.launch("capture")
                            }

                            ToolTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: root.recording ? "Stop Recording" : "Record"
                                glyph: root.recording
                                    ? String.fromCodePoint(0xF04DB)
                                    : String.fromCodePoint(0xF044A)
                                danger: root.recording
                                enabledAction: root.captureTarget?.enabled ?? false
                                onActivated: root.openRecord()
                            }

                            ToolTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: "Clipboard"
                                glyph: root.glyphFor("clipboard", String.fromCodePoint(0xF014D))
                                enabledAction: root.target("clipboard")?.enabled ?? false
                                onActivated: root.launch("clipboard")
                            }

                            ToolTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: "Windows"
                                glyph: root.glyphFor("windows", String.fromCodePoint(0xF05B9))
                                enabledAction: root.target("windows")?.enabled ?? false
                                onActivated: root.launch("windows")
                            }

                            ToolTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: "Displays"
                                glyph: root.glyphFor("displays", String.fromCodePoint(0xF0379))
                                enabledAction: root.target("displays")?.enabled ?? false
                                onActivated: root.launch("displays")
                            }

                            ToolTile {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: "Settings"
                                glyph: root.glyphFor("settings", String.fromCodePoint(0xF0493))
                                enabledAction: root.target("settings")?.enabled ?? false
                                onActivated: root.launch("settings")
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.minimumWidth: 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    PanelCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 142

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 94
                                Layout.fillHeight: true
                                radius: 14
                                color: K4Theme.panelSurfaceHi
                                clip: true

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
                                    font.pixelSize: 28
                                    renderType: Text.NativeRendering
                                }
                            }

                            ColumnLayout {
                                Layout.minimumWidth: 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 2

                                Text {
                                    text: "NOW PLAYING"
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: K4Media.hasPlayer
                                        && K4Media.activePlayer.trackTitle.length > 0
                                            ? K4Media.activePlayer.trackTitle
                                            : "Nothing playing"
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: K4Media.hasPlayer
                                        ? K4Media.activePlayer.trackArtist : ""
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    renderType: Text.NativeRendering
                                }

                                Item { Layout.fillHeight: true }

                                Item {
                                    Layout.minimumWidth: 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: K4Media.hasTimeline ? 10 : 0
                                    visible: K4Media.hasTimeline

                                    Rectangle {
                                        id: mediaTimeline
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 4
                                        radius: 2
                                        color: "#2a313a"

                                        Rectangle {
                                            width: mediaTimeline.width * Math.max(0, Math.min(1,
                                                (K4Media.activePlayer?.position ?? 0)
                                                    / Math.max(1, K4Media.activePlayer?.length ?? 1)))
                                            height: parent.height
                                            radius: parent.radius
                                            color: K4Theme.ink
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: K4Media.activePlayer?.canSeek
                                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        enabled: K4Media.activePlayer?.canSeek ?? false
                                        onPressed: function(event) {
                                            K4Media.seekTo(event.x / Math.max(1, width))
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    spacing: 7

                                    K4PanelButton {
                                        glyph: K4Theme.ico.prev
                                        glyphSize: 14
                                        activeColor: K4Theme.panelSurfaceHi
                                        enabledAction: K4Media.hasPlayer
                                            && K4Media.activePlayer.canGoPrevious
                                        onActivated: K4Media.previous()
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: 17
                                        color: K4Theme.ink
                                        opacity: K4Media.hasPlayer
                                            && K4Media.activePlayer.canTogglePlaying ? 1 : 0.38

                                        Text {
                                            anchors.centerIn: parent
                                            text: K4Media.isPlaying
                                                ? K4Theme.ico.pause : K4Theme.ico.play
                                            color: "#071017"
                                            font.family: K4Theme.iconFont
                                            font.pixelSize: 16
                                            renderType: Text.NativeRendering
                                        }

                                        TapHandler {
                                            enabled: K4Media.hasPlayer
                                                && K4Media.activePlayer.canTogglePlaying
                                            cursorShape: Qt.PointingHandCursor
                                            onTapped: K4Media.togglePlaying()
                                        }
                                    }

                                    K4PanelButton {
                                        glyph: K4Theme.ico.next
                                        glyphSize: 14
                                        activeColor: K4Theme.panelSurfaceHi
                                        enabledAction: K4Media.hasPlayer
                                            && K4Media.activePlayer.canGoNext
                                        onActivated: K4Media.next()
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        visible: K4Media.hasTimeline
                                        text: K4Media.formatTime(K4Media.activePlayer?.position ?? 0)
                                            + " / "
                                            + K4Media.formatTime(K4Media.activePlayer?.length ?? 0)
                                        color: K4Theme.dim
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 7
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }
                        }
                    }

                    PanelCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 7

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 15

                                Text {
                                    text: "Desktop tools"
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Open in island"
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    renderType: Text.NativeRendering
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                rows: 2
                                columnSpacing: 7
                                rowSpacing: 7

                                DesktopTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    title: "Files"
                                    subtitle: "Recent locations"
                                    glyph: root.glyphFor("files", String.fromCodePoint(0xF024B))
                                    enabledAction: root.target("files")?.enabled ?? false
                                    onActivated: root.launch("files")
                                }

                                DesktopTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    title: "System"
                                    subtitle: "CPU · memory · uptime"
                                    glyph: root.glyphFor("system", String.fromCodePoint(0xF0493))
                                    enabledAction: root.target("system")?.enabled ?? false
                                    onActivated: root.launch("system")
                                }

                                DesktopTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    title: "Weather"
                                    subtitle: root.weatherSubtitle()
                                    glyph: K4Weather.ready
                                        ? K4Weather.icon(K4Weather.current.wCode)
                                        : root.glyphFor("weather", String.fromCodePoint(0xF0595))
                                    enabledAction: root.target("weather")?.enabled ?? false
                                    onActivated: root.launch("weather")
                                }

                                DesktopTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    title: "Session"
                                    subtitle: "Lock · logout · power"
                                    glyph: root.glyphFor("session", String.fromCodePoint(0xF033E))
                                    enabledAction: root.target("session")?.enabled ?? false
                                    onActivated: root.launch("session")
                                }
                            }
                        }
                    }
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
