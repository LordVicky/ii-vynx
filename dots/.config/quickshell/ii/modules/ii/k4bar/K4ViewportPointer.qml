import QtQuick

// Stationary viewport pointer used by scrollable K4 surfaces. Delegates can
// move beneath it while Flickable content changes, so hover is derived from
// viewport coordinates rather than delegate-local hover events.
Item {
    id: root

    required property var surface
    property real pointerX: -1
    property real pointerY: -1

    readonly property bool active: pointerX >= 0 && pointerY >= 0

    function contains(item) {
        if (!active || !surface || !item || !item.visible)
            return false

        // Explicitly read scroll + delegate geometry so bindings using
        // contains() are invalidated while content moves under a still cursor.
        const dependency = surface.contentX + surface.contentY
            + item.x + item.y + item.width + item.height
        if (!Number.isFinite(dependency))
            return false

        const point = item.mapFromItem(surface, pointerX, pointerY)
        return point.x >= 0 && point.x < item.width
            && point.y >= 0 && point.y < item.height
    }

    MouseArea {
        parent: root.surface
        anchors.fill: root.surface
        z: 1000
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        scrollGestureEnabled: false

        onEntered: {
            root.pointerX = mouseX
            root.pointerY = mouseY
        }
        onPositionChanged: mouse => {
            root.pointerX = mouse.x
            root.pointerY = mouse.y
        }
        onExited: {
            root.pointerX = -1
            root.pointerY = -1
        }
        onWheel: wheel => wheel.accepted = false
    }
}
