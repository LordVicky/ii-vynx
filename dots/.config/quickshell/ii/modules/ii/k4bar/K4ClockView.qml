import QtQuick
import QtQuick.Layouts
import qs.modules.common

// Clock hover view adapted from pinned k4 ClockView.qml.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Item {
    id: root

    readonly property bool recording: Persistent.states.screenRecord.active

    function formatDuration(totalSeconds) {
        const mins = Math.floor(totalSeconds / 60)
        const secs = Math.floor(totalSeconds % 60)
        return String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0")
    }

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

    Item {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: K4Clock.date.toLocaleDateString(K4Clock.locale, "dddd")
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                font.capitalization: Font.Capitalize
                renderType: Text.NativeRendering
            }

            Text {
                text: K4Clock.date.toLocaleDateString(K4Clock.locale, "d MMMM")
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(K4Clock.date, "HH:mm")
            color: K4Theme.ink
            font.family: K4Theme.uiFont
            font.pixelSize: 30
            font.weight: Font.Light
            renderType: Text.NativeRendering
        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.recording

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
