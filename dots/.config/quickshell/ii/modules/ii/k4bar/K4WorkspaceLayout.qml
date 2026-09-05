pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// Proportional view of one Hyprland workspace. Client placement and size come
// directly from the existing HyprlandData snapshot through K4Windows, while
// pixels come from the matching native Wayland toplevel.
Item {
    id: root

    required property int workspaceId
    property bool interactive: false
    property bool mini: false
    property bool showLabels: interactive
    property int selectedIndex: -1
    property int draggingTargetWorkspace: -1
    property var draggingWindow: null
    property var draggingTargetWindow: null
    property string draggingDirection: ""

    signal highlighted(int index)
    signal activated(var row)
    signal closeRequested(var row)
    signal moveRequested(var row, int targetWorkspace)

    readonly property var workspaceRect: K4Windows.workspaceGeometry(root.workspaceId)
    readonly property real workspaceAspect: Math.max(0.2,
        Number(workspaceRect.width) / Math.max(1, Number(workspaceRect.height)))
    readonly property var rows: K4Windows.windowsForWorkspace(root.workspaceId)
    // Reuse ii-vynx's canonical wallpaper state. Prefer the generated thumbnail
    // so workspace previews also work for animated/video wallpapers.
    readonly property string wallpaperSource: {
        const thumbnail = String(Config.options.background.thumbnailPath || "")
        if (thumbnail.length > 0)
            return thumbnail
        return String(Config.options.background.wallpaperPath || "")
    }

    function restorePosition(item) {
        item.x = Qt.binding(function() { return item.layoutX })
        item.y = Qt.binding(function() { return item.layoutY })
    }

    function clearWindowDropTarget(row) {
        if (root.draggingTargetWindow?.address === row?.address) {
            root.draggingTargetWindow = null
            root.draggingDirection = ""
        }
    }

    Rectangle {
        id: canvas
        anchors.centerIn: parent
        width: Math.max(1, Math.min(parent.width,
            parent.height * root.workspaceAspect))
        height: Math.max(1, Math.min(parent.height,
            width / root.workspaceAspect))
        radius: root.mini ? 5 : 11
        color: root.mini ? K4Theme.panelSurfaceHi : "#090a0c"
        border.width: root.mini ? 0 : 1
        border.color: K4Theme.panelLine
        clip: root.mini

        Image {
            id: workspaceWallpaper
            anchors.fill: parent
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            z: 0
        }

        Rectangle {
            anchors.fill: parent
            color: root.mini ? "#12000000" : "#18000000"
            z: 0.5
        }

        Text {
            visible: root.rows.length === 0 && !root.mini
            anchors.centerIn: parent
            text: "Empty workspace"
            color: K4Theme.panelDim
            font.family: K4Theme.uiFont
            font.pixelSize: 11
            renderType: Text.NativeRendering
            z: 2
        }

        Repeater {
            model: root.rows

            delegate: Item {
                id: windowItem
                required property var modelData
                required property int index

                readonly property var layoutGeometry:
                    K4Windows.windowGeometry(windowItem.modelData)
                readonly property real layoutX:
                    canvas.width * Number(layoutGeometry.x)
                readonly property real layoutY:
                    canvas.height * Number(layoutGeometry.y)
                readonly property real layoutWidth: Math.max(root.mini ? 2 : 24,
                    canvas.width * Number(layoutGeometry.width))
                readonly property real layoutHeight: Math.max(root.mini ? 2 : 18,
                    canvas.height * Number(layoutGeometry.height))
                readonly property var toplevel:
                    K4Windows.toplevelFor(windowItem.modelData)
                readonly property bool selected:
                    root.selectedIndex === windowItem.index
                readonly property bool fullscreen:
                    K4Windows.isFullscreen(windowItem.modelData)
                readonly property bool floating:
                    Boolean(windowItem.modelData?.floating)
                property bool dragging: false
                property bool dropHover: false

                x: windowItem.layoutX
                y: windowItem.layoutY
                width: windowItem.layoutWidth
                height: windowItem.layoutHeight

                // Fullscreen owns the workspace visually, but in an overview it
                // stays behind the other clients so windows hidden by fullscreen
                // remain reachable. Dragging always rises above every preview.
                z: windowItem.dragging ? 1000
                    : windowItem.fullscreen ? 1
                    : windowItem.floating ? 100 + windowItem.index
                    : 20 + windowItem.index

                Rectangle {
                    anchors.fill: parent
                    radius: root.mini ? 3 : 8
                    color: K4Theme.panelSurfaceHot
                    border.width: !root.mini && (windowItem.selected || windowItem.dropHover) ? 2 : 1
                    border.color: !root.mini && (windowItem.selected || windowItem.dropHover)
                        ? K4Theme.blue : Qt.rgba(1, 1, 1, root.mini ? 0.16 : 0.10)
                    clip: true

                    Image {
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.38, root.mini ? 14 : 48)
                        height: width
                        source: K4Windows.appIcon(windowItem.modelData)
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        opacity: windowItem.toplevel ? 0 : 0.82
                    }

                    Loader {
                        anchors.fill: parent
                        active: windowItem.toplevel !== null
                        sourceComponent: ScreencopyView {
                            captureSource: windowItem.toplevel
                            live: true
                            smooth: true
                            layer.enabled: true
                            layer.smooth: true
                            layer.mipmap: true
                        }
                    }

                    Rectangle {
                        visible: !root.mini
                        anchors.fill: parent
                        color: windowItem.dragging
                            ? Qt.rgba(0.04, 0.52, 1, 0.16)
                            : windowItem.dropHover
                                ? Qt.rgba(0.04, 0.52, 1, 0.12)
                                : windowMouse.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.045)
                                    : windowItem.selected
                                        ? Qt.rgba(0.04, 0.52, 1, 0.07)
                                        : "transparent"
                    }

                    Rectangle {
                        visible: !root.mini && windowItem.fullscreen
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 8
                        width: fullscreenLabel.implicitWidth + 14
                        height: 21
                        radius: 10.5
                        color: "#bb000000"
                        border.width: 1
                        border.color: K4Theme.panelLine
                        z: 4

                        Text {
                            id: fullscreenLabel
                            anchors.centerIn: parent
                            text: "Fullscreen"
                            color: K4Theme.panelInkSoft
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                    }

                    Rectangle {
                        visible: root.showLabels
                            && (windowMouse.containsMouse || windowItem.selected)
                            && windowItem.width >= 100 && windowItem.height >= 54
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.min(34, parent.height * 0.28)
                        color: "#d9000000"

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 7
                            anchors.rightMargin: 7
                            spacing: 6

                            Image {
                                width: 18
                                height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                source: K4Windows.appIcon(windowItem.modelData)
                                sourceSize: Qt.size(28, 28)
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                width: Math.max(0, parent.width - 24)
                                anchors.verticalCenter: parent.verticalCenter
                                text: K4Windows.appName(windowItem.modelData)
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                // Mirrors ii-vynx OverviewWidget's window-to-window drop seam.
                // Dropping on either half of another preview determines the
                // native scrolling/tiled swap direction.
                DropArea {
                    anchors.fill: parent
                    enabled: root.interactive
                        && root.draggingWindow !== null
                        && root.draggingWindow?.address !== windowItem.modelData?.address

                    onEntered: function(drag) {
                        windowItem.dropHover = true
                        root.draggingTargetWindow = windowItem.modelData
                        root.draggingDirection = drag.x < width / 2 ? "l" : "r"
                    }
                    onExited: {
                        windowItem.dropHover = false
                        root.clearWindowDropTarget(windowItem.modelData)
                    }
                }

                MouseArea {
                    id: windowMouse
                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: true
                    cursorShape: windowItem.dragging
                        ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    drag.target: root.interactive ? windowItem : null
                    drag.axis: Drag.XAndYAxis

                    onEntered: root.highlighted(windowItem.index)
                    onPressed: function(mouse) {
                        if (mouse.button !== Qt.LeftButton)
                            return

                        root.draggingWindow = windowItem.modelData
                        root.draggingTargetWindow = null
                        root.draggingDirection = ""
                        windowItem.dragging = true

                        // Use the exact explicit lifecycle that the working
                        // ii-vynx overview uses. The hotspot must be the press
                        // point so DropAreas track the pointer, not the card's
                        // center while the preview moves.
                        windowItem.Drag.source = windowItem
                        windowItem.Drag.hotSpot.x = mouse.x
                        windowItem.Drag.hotSpot.y = mouse.y
                        windowItem.Drag.active = true
                    }
                    onReleased: function(mouse) {
                        if (!windowItem.dragging)
                            return

                        // Capture the drop target before disabling Drag.active;
                        // disabling it causes DropArea.onExited to run.
                        const row = windowItem.modelData
                        const targetWorkspace = root.draggingTargetWorkspace
                        const targetRow = root.draggingTargetWindow
                        const direction = root.draggingDirection

                        windowItem.dragging = false
                        windowItem.Drag.active = false
                        root.draggingWindow = null
                        root.draggingTargetWindow = null
                        root.draggingDirection = ""
                        root.restorePosition(windowItem)

                        if (targetWorkspace > 0
                                && targetWorkspace !== root.workspaceId) {
                            root.moveRequested(row, targetWorkspace)
                            return
                        }

                        if (targetRow?.address
                                && targetRow.address !== row?.address)
                            K4Windows.swapWindows(row, targetRow, direction)
                    }
                    onCanceled: {
                        windowItem.dragging = false
                        windowItem.Drag.active = false
                        root.draggingWindow = null
                        root.draggingTargetWindow = null
                        root.draggingDirection = ""
                        root.restorePosition(windowItem)
                    }
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.MiddleButton)
                            root.closeRequested(windowItem.modelData)
                        else if (!windowItem.dragging)
                            root.activated(windowItem.modelData)
                    }
                }
            }
        }
    }
}
