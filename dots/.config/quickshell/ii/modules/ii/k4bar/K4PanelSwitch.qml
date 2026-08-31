import QtQuick

Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 34
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? K4Theme.blue : K4Theme.surfaceHi

        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: K4Theme.ink

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
