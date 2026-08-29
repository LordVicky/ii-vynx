import QtQuick

// ListView hover that stays tied to the stationary viewport while delegates
// move underneath it. Delegate hover events update the pointer during normal
// cursor motion; wheel events update it during stationary-pointer scrolling.
ListView {
    id: root

    property real rowHeight: 42
    property real trackedPointerY: -1

    readonly property real rowStride: Math.max(1, rowHeight + spacing)
    readonly property int hoveredIndex: {
        if (!viewportHover.hovered || trackedPointerY < 0 || count <= 0)
            return -1

        const relativeY = trackedPointerY + contentY - originY
        if (relativeY < 0)
            return -1

        const candidate = Math.floor(relativeY / rowStride)
        return candidate >= 0 && candidate < count ? candidate : -1
    }

    function rememberPointer(y) {
        if (Number.isFinite(y))
            trackedPointerY = y
    }

    HoverHandler {
        id: viewportHover
        blocking: false

        // Use HoverHandler only for viewport membership. Live testing showed its
        // point can latch at entry in this nested ListView path, so moving
        // delegates feed pointer coordinates explicitly instead.
        onHoveredChanged: {
            if (hovered)
                root.rememberPointer(point.position.y)
            else
                root.trackedPointerY = -1
        }
    }

    WheelHandler {
        id: wheelTracker
        target: null
        blocking: false
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.rememberPointer(event.y)
    }
}
