import QtQuick
import qs
import qs.modules.common

// Shared drag-to-resize handle for AbstractBackgroundWidget subclasses.
// Mirrors the resizeHandle/resizeArea pattern from
// widgets/images/CustomImage.qml, with two host-selectable modes:
//
//   mode: "scale"  continuous zoom. Emits requestScale/requestCommit with a
//                  scalar multiplier instead of an absolute pixel size, so it
//                  applies uniformly across widgets with very different content.
//   mode: "size"   discrete/absolute sizing. Emits requestSize with the dragged
//                  width/height in px and lets the host snap them to whatever
//                  layout modes it supports (calendar, worldclock).
Rectangle {
    id: handle

    property Item hostWidget          // the AbstractBackgroundWidget root (for containsMouse)
    property string mode: "scale"     // "scale" | "size"
    property real handleMargins: 6
    property int handleCursor: mode === "size" ? Qt.SizeHorCursor : Qt.SizeFDiagCursor

    // mode: "scale"
    property real currentScale: 1     // current widgetScale, driven by the host
    property real baseSize: 100        // UNSCALED reference dimension in px (host content implicit width)
    property real minScale: 0.5
    property real maxScale: 3.0
    signal requestScale(real newScale) // emitted live during drag
    signal requestCommit(real newScale)// emitted on release

    // mode: "size"
    property real currentWidth: 0      // current rendered width in px, driven by the host
    property real currentHeight: 0     // current rendered height in px, driven by the host
    signal requestSize(real newWidth, real newHeight) // emitted live during drag
    signal requestSizeCommit()                        // emitted on release

    width: 16
    height: 16
    radius: 4
    color: Appearance.colors.colOnPrimaryContainer
    anchors {
        right: parent.right
        bottom: parent.bottom
        margins: handle.handleMargins
    }
    opacity: ((hostWidget && hostWidget.containsMouse) || resizeArea.containsMouse || resizeArea.pressed) ? 0.5 : 0
    visible: opacity > 0 && !Config.options.background.widgetsLocked
    z: 100

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    MouseArea {
        id: resizeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: handle.handleCursor
        preventStealing: true

        property real startScale: 1
        property real startWidth: 0
        property real startHeight: 0
        property real startX: 0
        property real startY: 0

        onPressed: (mouse) => {
            startScale = handle.currentScale
            startWidth = handle.currentWidth
            startHeight = handle.currentHeight
            var g = mapToItem(null, mouse.x, mouse.y)
            startX = g.x
            startY = g.y
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            var g = mapToItem(null, mouse.x, mouse.y)
            if (handle.mode === "size") {
                handle.requestSize(startWidth + (g.x - startX), startHeight + (g.y - startY))
                return
            }
            var delta = Math.max(g.x - startX, g.y - startY)
            var ns = startScale + delta / Math.max(1, handle.baseSize)
            ns = Math.max(handle.minScale, Math.min(handle.maxScale, ns))
            handle.requestScale(ns)
        }
        onReleased: {
            if (handle.mode === "size")
                handle.requestSizeCommit()
            else
                handle.requestCommit(handle.currentScale)
        }
    }
}
