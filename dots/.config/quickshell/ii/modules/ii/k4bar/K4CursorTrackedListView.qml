import QtQuick

// ListView hover that stays tied to the stationary viewport while delegates
// move underneath it. Qt hover state on moving delegate MouseAreas is event-
// driven and can become stale during wheel/trackpad scrolling, so remember the
// pointer in viewport coordinates and derive the row from content motion.
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

        onPointChanged: {
            if (hovered)
                root.rememberPointer(point.position.y)
        }

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
