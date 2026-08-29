import QtQuick

// GridView variant of the validated connection-list hover tracker. The
// MouseArea remains part of the scrolling root so its viewport relationship is
// identical to the working K4CursorTrackedListView implementation.
GridView {
    id: root

    property real trackedPointerX: -1
    property real trackedPointerY: -1
    property real hoverWidth: cellWidth
    property real hoverHeight: cellHeight

    readonly property int trackedColumns: Math.max(1,
        Math.floor(width / Math.max(1, cellWidth)))
    readonly property int hoveredIndex: {
        if (trackedPointerX < 0 || trackedPointerY < 0 || count <= 0)
            return -1

        const relativeX = trackedPointerX + contentX - originX
        const relativeY = trackedPointerY + contentY - originY
        if (relativeX < 0 || relativeY < 0)
            return -1

        const column = Math.floor(relativeX / Math.max(1, cellWidth))
        const row = Math.floor(relativeY / Math.max(1, cellHeight))
        if (column < 0 || column >= trackedColumns || row < 0)
            return -1

        const candidate = row * trackedColumns + column
        if (candidate < 0 || candidate >= count)
            return -1

        const offsetX = relativeX - column * cellWidth
        const offsetY = relativeY - row * cellHeight
        return offsetX >= 0 && offsetX < hoverWidth
            && offsetY >= 0 && offsetY < hoverHeight
            ? candidate : -1
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
            root.trackedPointerX = mouseX
            root.trackedPointerY = mouseY
        }
        onPositionChanged: mouse => {
            root.trackedPointerX = mouse.x
            root.trackedPointerY = mouse.y
        }
        onExited: {
            root.trackedPointerX = -1
            root.trackedPointerY = -1
        }
        onWheel: wheel => wheel.accepted = false
    }
}
