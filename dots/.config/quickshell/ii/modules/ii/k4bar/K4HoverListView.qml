import QtQuick

ListView {
    id: root

    readonly property int hoveredIndex: viewportHover.hovered
        ? root.indexAt(
            viewportHover.point.position.x + root.contentX,
            viewportHover.point.position.y + root.contentY
        )
        : -1

    HoverHandler {
        id: viewportHover
        blocking: false
    }
}
