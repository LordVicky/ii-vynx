import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common

// Recording pill uses ii-vynx's existing recorder state/action owner.
Item {
    id: root

    property bool interactive: true
    readonly property bool recording: Persistent.states.screenRecord.active

    implicitWidth: row.implicitWidth
    implicitHeight: 22
    visible: recording

    function formatDuration(totalSeconds) {
        const mins = Math.floor(totalSeconds / 60)
        const secs = Math.floor(totalSeconds % 60)
        return String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0")
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
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

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive && root.recording
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: Quickshell.execDetached(Directories.recordScriptPath)
    }
}
