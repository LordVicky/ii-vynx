import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PanelWindow {
    id: root

    required property bool surfaceActive
    required property bool showBarBackground

    visible: root.surfaceActive && root.showBarBackground
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitHeight: Appearance.sizes.baseBarHeight + Appearance.rounding.screenRounding

    WlrLayershell.namespace: "quickshell:bar-glass"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        left: true
        right: true
        top: !Config.options.bar.bottom
        bottom: Config.options.bar.bottom
    }

    // This surface is visual only. The existing bar keeps all pointer, scroll,
    // hover and exclusive-zone behavior.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        id: barBody

        anchors {
            left: parent.left
            right: parent.right
            top: !Config.options.bar.bottom ? parent.top : undefined
            bottom: Config.options.bar.bottom ? parent.bottom : undefined
        }
        height: Appearance.sizes.baseBarHeight
        color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
    }

    Item {
        id: decorators

        anchors {
            left: parent.left
            right: parent.right
            top: !Config.options.bar.bottom ? barBody.bottom : undefined
            bottom: Config.options.bar.bottom ? barBody.top : undefined
        }
        height: Appearance.rounding.screenRounding

        RoundCorner {
            id: leftCorner

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            implicitSize: Appearance.rounding.screenRounding
            color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
            corner: Config.options.bar.bottom
                ? RoundCorner.CornerEnum.BottomLeft
                : RoundCorner.CornerEnum.TopLeft
        }

        RoundCorner {
            id: rightCorner

            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            implicitSize: Appearance.rounding.screenRounding
            color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
            corner: Config.options.bar.bottom
                ? RoundCorner.CornerEnum.BottomRight
                : RoundCorner.CornerEnum.TopRight
        }
    }
}
