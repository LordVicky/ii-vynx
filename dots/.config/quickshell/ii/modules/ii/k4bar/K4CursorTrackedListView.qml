import QtQuick

// Fixed-row ListView specialization on top of the shared viewport pointer.
// Deriving the row from content motion keeps hover under a stationary cursor.
ListView {
    id: root

    property real rowHeight: 42
    readonly property real trackedPointerY: viewportPointer.pointerY

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

    K4ViewportPointer {
        id: viewportPointer
        surface: root
    }
}
