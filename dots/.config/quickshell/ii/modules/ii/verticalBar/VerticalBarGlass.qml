import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PanelWindow {
    id: root

    required property bool surfaceActive
    required property bool showBarBackground
    property var segments: []
    property real autoHideOffset: 0

    readonly property bool hugStyle: Config.options.bar.cornerStyle === 0
    readonly property bool floatStyle: Config.options.bar.cornerStyle === 1
    readonly property bool rightSide: Config.options.bar.bottom
    readonly property real edgeInset: root.floatStyle ? Appearance.sizes.hyprlandGapsOut : 0
    readonly property bool unifiedSegmentsVisible: GlobalStates.unifiedBarGlassSegmentsEnabled
        && !root.showBarBackground
        && root.segments.length > 0

    visible: root.surfaceActive && (root.showBarBackground || root.unifiedSegmentsVisible)
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitWidth: Appearance.sizes.baseVerticalBarWidth
        + (root.showBarBackground && root.hugStyle ? Appearance.rounding.screenRounding : 0)

    WlrLayershell.namespace: "quickshell:bar-glass"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        bottom: true
        left: !root.rightSide
        right: root.rightSide
    }

    margins {
        left: !root.rightSide
            ? root.edgeInset + root.autoHideOffset
            : 0
        right: root.rightSide
            ? root.edgeInset + root.autoHideOffset
            : 0
        top: root.unifiedSegmentsVisible ? 0 : (root.floatStyle ? Appearance.sizes.hyprlandGapsOut : 0)
        bottom: root.unifiedSegmentsVisible ? 0 : (root.floatStyle ? Appearance.sizes.hyprlandGapsOut : 0)
    }

    // Visual only. The existing quickshell:verticalBar window remains the sole
    // owner of hover, scroll, clicks, focus and exclusive-zone behavior.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        id: barBody

        visible: root.showBarBackground
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: !root.rightSide ? parent.left : undefined
            right: root.rightSide ? parent.right : undefined
        }
        width: Appearance.sizes.baseVerticalBarWidth
        color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
        radius: root.floatStyle ? Appearance.rounding.windowRounding : 0
        antialiasing: root.floatStyle
    }

    Item {
        id: decorators

        visible: root.showBarBackground && root.hugStyle
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: !root.rightSide ? barBody.right : undefined
            right: root.rightSide ? barBody.left : undefined
        }
        width: Appearance.rounding.screenRounding

        RoundCorner {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            implicitSize: Appearance.rounding.screenRounding
            color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
            corner: root.rightSide
                ? RoundCorner.CornerEnum.TopRight
                : RoundCorner.CornerEnum.TopLeft
        }

        RoundCorner {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            implicitSize: Appearance.rounding.screenRounding
            color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
            corner: root.rightSide
                ? RoundCorner.CornerEnum.BottomRight
                : RoundCorner.CornerEnum.BottomLeft
        }
    }

    Repeater {
        model: root.unifiedSegmentsVisible ? root.segments : []

        delegate: Rectangle {
            required property var modelData

            x: 4
            y: Math.round(modelData.resolvedPosition)
            width: Math.max(1, Appearance.sizes.baseVerticalBarWidth - 8)
            height: Math.max(1, modelData.resolvedExtent)
            color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
            topLeftRadius: modelData.startRadius
            topRightRadius: modelData.startRadius
            bottomLeftRadius: modelData.endRadius
            bottomRightRadius: modelData.endRadius
            antialiasing: true
        }
    }
}
