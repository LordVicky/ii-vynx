import QtQuick

// Track hover from a MouseArea pinned to the ListView viewport rather than from
// delegates that move underneath a stationary cursor. The overlay accepts no
// buttons, so row/button interaction remains owned by the delegates.
ListView {
    id: root

    property real rowHeight: 42
    property real trackedPointerY: -1

    readonly property real rowStride: Math.max(1, rowHeight + spacing)
    readonly property int hoveredIndex: {
        if (trackedPointerY < 0 || count <= 0)
            return -1

        const relativeY = trackedPointerY + contentY - originY
        if (relativeY < 0)
            return -1

        const candidate = Math.floor(relativeY / rowStride)
        if (candidate < 0 || candidate >= count)
            return -1

        const offsetInRow = relativeY - candidate * rowStride
        return offsetInRow >= 0 && offsetInRow < rowHeight ? candidate : -1
    }

    function trace(event, y) {
        console.warn(
            "[K4Hover][list]", event,
            "y=", y,
            "tracked=", trackedPointerY,
            "contentY=", contentY,
            "originY=", originY,
            "index=", hoveredIndex,
            "contains=", viewportMouse.containsMouse,
            "size=", width + "x" + height,
            "count=", count
        )
    }

    Component.onCompleted: trace("ready", -1)
    onTrackedPointerYChanged: trace("tracked", trackedPointerY)
    onHoveredIndexChanged: trace("index", trackedPointerY)
    onContentYChanged: {
        if (moving)
            trace("content", trackedPointerY)
    }

    MouseArea {
        id: viewportMouse
        parent: root
        anchors.fill: root
        z: 1000
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        scrollGestureEnabled: false

        onEntered: {
            root.trackedPointerY = mouseY
            root.trace("enter", mouseY)
        }
        onPositionChanged: mouse => {
            root.trackedPointerY = mouse.y
            root.trace("move", mouse.y)
        }
        onExited: {
            root.trace("exit", mouseY)
            root.trackedPointerY = -1
        }
        onWheel: wheel => {
            root.trace("wheel", wheel.y)
            wheel.accepted = false
        }
    }
}
