import QtQuick
import QtQuick.Layouts

// Horizontal switcher adapted from pinned k4 WindowsView.
Item {
    id: root
    required property var plugin
    focus: true
    property real dwell: 0
    readonly property int dwellDelay: 900

    Component.onCompleted: {
        fade.start()
        forceActiveFocus()
    }
    opacity: 0
    NumberAnimation { id: fade; target: root; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }

    Timer {
        id: dwellTimer
        interval: 40; repeat: true
        running: root.plugin.open && root.plugin.count > 0
        onTriggered: {
            root.dwell += interval
            if (root.dwell >= root.dwellDelay) {
                stop()
                root.plugin.choose()
            }
        }
    }
    function resetDwell() { dwell = 0; dwellTimer.restart() }
    Connections { target: root.plugin; function onIndexChanged() { root.resetDwell() } }

    Keys.onPressed: function(event) {
        root.resetDwell()
        if (event.key === Qt.Key_Escape) { root.plugin.close(); event.accepted = true }
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) { root.plugin.advance(); event.accepted = true }
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) { root.plugin.retreat(); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { root.plugin.choose(); event.accepted = true }
        else if (event.key === Qt.Key_Delete || event.key === Qt.Key_W) { root.plugin.closeCurrent(); event.accepted = true }
    }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Alt) {
            root.plugin.choose(); event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            spacing: 8
            Repeater {
                model: root.plugin.entries
                Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.plugin.index
                    Layout.preferredWidth: 120
                    Layout.fillHeight: true
                    radius: 12
                    color: selected ? K4Theme.surfaceHi : cardMouse.containsMouse ? K4Theme.surface : "transparent"
                    border.width: selected ? 1 : 0
                    border.color: K4Theme.blue
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 5
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: String.fromCodePoint(0xF08C6)
                            color: card.selected ? K4Theme.ink : K4Theme.muted
                            font.family: K4Theme.iconFont; font.pixelSize: 34
                        }
                        Text {
                            Layout.fillWidth: true
                            text: K4Windows.appName(card.modelData)
                            color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 11
                            font.weight: card.selected ? Font.DemiBold : Font.Normal
                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        visible: K4Windows.workspace(card.modelData).length > 0
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
                        width: Math.max(16, workspaceText.implicitWidth + 8); height: 15; radius: 7
                        color: card.selected ? K4Theme.blue : "#66000000"
                        Text { id: workspaceText; anchors.centerIn: parent; text: K4Windows.workspace(card.modelData); color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 9; font.weight: Font.DemiBold }
                    }
                    Rectangle {
                        visible: card.selected
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 4
                        height: 3; radius: 1.5; color: K4Theme.track
                        Rectangle { width: parent.width * Math.min(1, root.dwell / root.dwellDelay); height: parent.height; radius: parent.radius; color: K4Theme.blue }
                    }
                    MouseArea {
                        id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onEntered: root.plugin.index = card.index
                        onClicked: function(mouse) {
                            root.plugin.index = card.index
                            if (mouse.button === Qt.MiddleButton) root.plugin.closeCurrent()
                            else root.plugin.choose()
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.plugin.entries[root.plugin.index] ? K4Windows.title(root.plugin.entries[root.plugin.index]) : ""
            color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
        }
        Text {
            Layout.fillWidth: true
            text: "tab cycles · pauses to focus · delete closes · esc cancels"
            color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
