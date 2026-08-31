import QtQuick

Rectangle {
    id: root

    property bool interactive: true
    readonly property bool hovered: hover.hovered
    signal activated()

    radius: 13
    color: hover.hovered && interactive ? K4Theme.surfaceHi : K4Theme.surface

    Behavior on color { ColorAnimation { duration: 120 } }

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
