import QtQuick

Rectangle {
    id: root

    property bool interactive: true
    property color baseColor: K4Theme.panelSurfaceHi
    property color hoverColor: K4Theme.panelSurfaceHot
    property color borderColor: K4Theme.panelLine
    property color hoverBorderColor: K4Theme.panelLineStrong
    property real cornerRadius: 13
    readonly property bool hovered: hover.hovered
    signal activated()

    radius: cornerRadius
    color: hover.hovered && interactive ? hoverColor : baseColor
    border.width: 1
    border.color: hover.hovered && interactive ? hoverBorderColor : borderColor

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    HoverHandler { id: hover; enabled: root.interactive }

    // Keep the tile click behind its content. Nested controls such as the
    // Wi-Fi/Bluetooth radio buttons then win hit-testing and do not also open
    // the detail page, matching pinned k4's two-action tile behavior.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
