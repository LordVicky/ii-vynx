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
    TapHandler {
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onTapped: root.activated()
    }
}
