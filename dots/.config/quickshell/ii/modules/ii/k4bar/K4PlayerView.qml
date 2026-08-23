import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// Player hover view adapted from pinned k4 PlayerView.qml.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Item {
    id: root

    readonly property var player: K4Media.activePlayer
    readonly property real progress: player && player.length > 0
        ? Math.max(0, Math.min(1, player.position / player.length)) : 0

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

    component MediaButton: Item {
        id: button
        required property string glyph
        property int glyphSize: 20
        property color glyphColor: K4Theme.ink
        property bool enabledAction: true
        signal activated()

        implicitWidth: 34
        implicitHeight: 30
        opacity: enabledAction ? 1 : 0.3

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: button.glyphColor
            font.family: K4Theme.iconFont
            font.pixelSize: button.glyphSize
            renderType: Text.NativeRendering
        }

        MouseArea {
            anchors.fill: parent
            enabled: button.enabledAction
            cursorShape: button.enabledAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.activated()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 13

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 11

            ClippingRectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                radius: 7
                color: K4Theme.surface

                Image {
                    id: cover
                    anchors.fill: parent
                    source: K4Media.coverFor(root.player)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 256
                    visible: status === Image.Ready
                }

                Image {
                    id: appIcon
                    anchors.fill: parent
                    anchors.margins: 9
                    source: K4Media.appIconFor(root.player)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    visible: !cover.visible && status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !cover.visible && !appIcon.visible
                    text: K4Theme.ico.music
                    color: K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 18
                    renderType: Text.NativeRendering
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle?.length > 0
                        ? root.player.trackTitle : "No playback"
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist?.length > 0
                        ? root.player.trackArtist : (root.player?.identity ?? "")
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }
            }

            Item {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 3
                            radius: 1.5
                            color: K4Theme.ink
                            height: [10, 16, 7, 13][index]
                            anchors.bottom: parent.bottom

                            SequentialAnimation on height {
                                running: K4Media.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation { to: 4 + (index % 2 === 0 ? 10 : 5); duration: 320 + index * 85; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 4; duration: 280 + index * 65; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 14 - index; duration: 300 + index * 40; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 5; duration: 260 + index * 55; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            K4RecordingPill {
                interactive: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 12
            spacing: 8
            visible: K4Media.hasTimeline

            Text {
                text: root.player ? K4Media.formatTime(root.player.position) : "0:00"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 10
                renderType: Text.NativeRendering
                Layout.preferredWidth: 28
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: seekTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekMouse.containsMouse ? 6 : 4
                    radius: height / 2
                    color: K4Theme.track

                    Behavior on height {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        width: seekTrack.width * root.progress
                        height: parent.height
                        radius: parent.radius
                        color: K4Theme.ink

                        Behavior on width {
                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }
                    }
                }

                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        K4Media.seekTo(mouse.x / width)
                    }
                }
            }

            Text {
                text: root.player && root.player.length > 0
                    ? "-" + K4Media.formatTime(root.player.length - root.player.position)
                    : "0:00"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                renderType: Text.NativeRendering
                Layout.preferredWidth: 32
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 0

            MediaButton {
                glyph: K4Theme.ico.shuffle
                glyphSize: 14
                glyphColor: root.player?.shuffle ? K4Theme.ink : K4Theme.muted
                enabledAction: !!root.player && root.player.shuffleSupported
                onActivated: root.player.shuffle = !root.player.shuffle
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            MediaButton {
                glyph: K4Theme.ico.prev
                glyphSize: 20
                enabledAction: !!root.player && root.player.canGoPrevious
                onActivated: K4Media.previous()
                Layout.alignment: Qt.AlignVCenter
            }

            MediaButton {
                glyph: K4Media.isPlaying ? K4Theme.ico.pause : K4Theme.ico.play
                glyphSize: 24
                enabledAction: !!root.player && root.player.canTogglePlaying
                onActivated: K4Media.togglePlaying()
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.alignment: Qt.AlignVCenter
            }

            MediaButton {
                glyph: K4Theme.ico.next
                glyphSize: 20
                enabledAction: !!root.player && root.player.canGoNext
                onActivated: K4Media.next()
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // Pinned k4 opens the panel's Sound tab from here. K4Panel is the
            // narrow global navigation seam; the ii sidebar stays independent.
            MediaButton {
                glyph: K4Theme.ico.output
                glyphSize: 15
                glyphColor: K4Theme.muted
                enabledAction: true
                onActivated: K4Panel.openTab("sonido")
                Layout.alignment: Qt.AlignVCenter
            }
        }

        K4NotifStrip {
            max: 3
            Layout.fillWidth: true
            Layout.topMargin: 2
        }
    }
}
