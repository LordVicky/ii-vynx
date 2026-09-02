import QtQuick

Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 36
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? K4Theme.panelBlue : K4Theme.panelSurfaceHot
        border.width: 1
        border.color: root.checked
            ? Qt.rgba(0.43, 0.66, 1, 0.42) : K4Theme.panelLineStrong

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? "#07111e" : K4Theme.panelInkSoft

            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }

    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: root.toggled()
    }
}
