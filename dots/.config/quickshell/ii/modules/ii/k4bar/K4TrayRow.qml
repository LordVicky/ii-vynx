import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

// Interactive tray row adapted from pinned k4 TrayRow. It renders the same
// live StatusNotifierItem objects already owned by ii-vynx TrayService.
RowLayout {
    id: root

    required property var trayPlugin
    property int max: 5
    property int iconSize: 16

    readonly property real uiScale: K4Settings.uiScale
    readonly property int shown: Math.min(K4Tray.count, max)

    visible: K4Tray.count > 0
    spacing: 4

    Repeater {
        model: K4Tray.sorted.slice(0, root.shown)

        delegate: Item {
            id: cell
            required property var modelData

            Layout.preferredWidth: root.iconSize + 8
            Layout.preferredHeight: root.iconSize + 6
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: 6
                visible: cellMouse.containsMouse
                color: K4Theme.surfaceHi
            }

            Image {
                anchors.centerIn: parent
                width: Math.round(root.iconSize * root.uiScale)
                height: Math.round(root.iconSize * root.uiScale)
                scale: 1 / root.uiScale
                source: cell.modelData.icon
                sourceSize.width: Math.ceil(root.iconSize * root.uiScale * 2)
                sourceSize.height: Math.ceil(root.iconSize * root.uiScale * 2)
                fillMode: Image.PreserveAspectFit
                opacity: cell.modelData.status === Status.NeedsAttention ? 1 : 0.85

                SequentialAnimation on opacity {
                    running: cell.modelData.status === Status.NeedsAttention
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        root.trayPlugin.openFor(cell.modelData)
                    } else if (mouse.button === Qt.MiddleButton) {
                        K4Tray.secondary(cell.modelData)
                    } else if (!K4Tray.primary(cell.modelData)) {
                        root.trayPlugin.openFor(cell.modelData)
                    }
                }

                onWheel: function(wheel) {
                    K4Tray.scroll(cell.modelData, wheel.angleDelta.y)
                }
            }
        }
    }

    Text {
        visible: K4Tray.count > root.shown
        text: "+" + (K4Tray.count - root.shown)
        color: K4Theme.muted
        font.family: K4Theme.uiFont
        font.pixelSize: Math.round(10 * root.uiScale)
        scale: 1 / root.uiScale
        Layout.alignment: Qt.AlignVCenter

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.trayPlugin.toggle()
        }
    }
}
