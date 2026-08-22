import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets

// Collapsed k4 pill adapted against the pinned upstream Idle view.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Item {
    id: root

    readonly property var activePlayer: K4Media.activePlayer
    readonly property bool hasPlayer: K4Media.hasPlayer
    readonly property bool isPlaying: K4Media.isPlaying
    readonly property string artSource: K4Media.coverFor(activePlayer)
    readonly property bool recording: Persistent.states.screenRecord.active

    readonly property var workspaces: K4Workspaces.list
    readonly property int activeWorkspaceId: K4Workspaces.activeId

    property bool started: false
    property bool showingWorkspaces: false
    property int workspaceStart: 0

    readonly property var visibleWorkspaces:
        workspaces.slice(workspaceStart, workspaceStart + 3)

    readonly property int leftReserve: isPlaying ? 53 : 0
    readonly property int rightMeasured: Math.ceil(rightIndicators.implicitWidth)
    readonly property int sideReserve: Math.max(leftReserve, rightMeasured)
    readonly property int desiredBodyWidth: 46 + 2 * sideReserve + 44

    function adjustWorkspaceWindow() {
        const list = workspaces
        if (list.length <= 3) {
            workspaceStart = 0
            return
        }

        let activeIndex = -1
        for (let i = 0; i < list.length; ++i) {
            if (list[i].id === activeWorkspaceId) {
                activeIndex = i
                break
            }
        }
        if (activeIndex < 0)
            return

        let start = Math.max(0, Math.min(workspaceStart, list.length - 3))
        if (activeIndex < start)
            start = activeIndex
        else if (activeIndex > start + 2)
            start = activeIndex - 2
        workspaceStart = Math.max(0, Math.min(start, list.length - 3))
    }

    function showWorkspaceChange() {
        adjustWorkspaceWindow()
        if (!started)
            return
        showingWorkspaces = true
        workspaceReturn.restart()
    }

    function formatDuration(totalSeconds) {
        const mins = Math.floor(totalSeconds / 60)
        const secs = Math.floor(totalSeconds % 60)
        return String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0")
    }

    Component.onCompleted: {
        adjustWorkspaceWindow()
        startupGuard.start()
    }

    Timer {
        id: startupGuard
        interval: 700
        onTriggered: root.started = true
    }

    Timer {
        id: workspaceReturn
        interval: 1800
        onTriggered: root.showingWorkspaces = false
    }

    Connections {
        target: K4Workspaces
        function onActiveIdChanged() { root.showWorkspaceChange() }
        function onListChanged() { root.adjustWorkspaceWindow() }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 11
        anchors.rightMargin: 11

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            ClippingRectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                visible: root.isPlaying
                radius: 4
                color: K4Theme.surface

                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.artSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 128
                    visible: status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !cover.visible
                    text: "music_note"
                    fill: 1
                    iconSize: 12
                    color: K4Theme.muted
                }
            }

            Item {
                Layout.preferredWidth: 17
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter
                visible: root.isPlaying

                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2.5

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            readonly property var restHeights: [9, 13, 6, 11]
                            width: 2.5
                            radius: 1.25
                            color: K4Theme.ink
                            height: restHeights[index]
                            anchors.bottom: parent.bottom

                            SequentialAnimation on height {
                                running: root.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation { to: 4 + (index % 2 === 0 ? 8 : 4); duration: 320 + index * 85; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 3; duration: 280 + index * 65; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 11 - index; duration: 300 + index * 40; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 4; duration: 260 + index * 55; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: parent.height

            Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(K4Clock.date, "HH:mm")
                font.family: K4Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: root.hasPlayer ? K4Theme.ink : K4Theme.muted
                opacity: root.showingWorkspaces ? 0 : 1
                renderType: Text.NativeRendering

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                opacity: root.showingWorkspaces ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: root.visibleWorkspaces
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool focused: modelData.focused
                        Layout.preferredWidth: focused ? 18 : 6
                        Layout.preferredHeight: 6
                        Layout.alignment: Qt.AlignVCenter
                        radius: 3
                        color: focused ? K4Theme.ink : K4Theme.track

                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
        }

        RowLayout {
            id: rightIndicators
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Item {
                visible: root.recording
                implicitWidth: recordingRow.implicitWidth
                implicitHeight: recordingRow.implicitHeight

                RowLayout {
                    id: recordingRow
                    anchors.fill: parent
                    spacing: 5

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        Layout.alignment: Qt.AlignVCenter
                        radius: 4
                        color: K4Theme.red

                        SequentialAnimation on opacity {
                            running: root.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        text: root.formatDuration(Persistent.states.screenRecord.seconds)
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
