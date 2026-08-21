import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.bar as Bar

PanelWindow {
    id: root

    required property var targetScreen
    required property bool surfaceActive
    required property real surfaceY
    required property real surfaceHeight
    required property real startRadius
    required property real endRadius

    readonly property bool rightSide: Config.options.bar.bottom
    readonly property real autoHideOffset: Number(GlobalStates.barAutoHideOffsets[root.targetScreen?.name ?? ""] ?? 0)
    readonly property real edgeInset: (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0) + 4
    readonly property string unifiedSegmentKey: `island:${Math.round(root.surfaceY * 1000)}:${Math.round(root.surfaceHeight * 1000)}`

    screen: root.targetScreen
    visible: root.surfaceActive
        && root.surfaceHeight > 0
        && !GlobalStates.unifiedBarGlassSegmentsEnabled
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitWidth: Math.max(1, Appearance.sizes.baseVerticalBarWidth - 8)
    implicitHeight: Math.max(1, root.surfaceHeight)

    WlrLayershell.namespace: "quickshell:bar-glass"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        left: !root.rightSide
        right: root.rightSide
    }

    margins {
        top: Math.round(root.surfaceY)
        left: !root.rightSide ? root.edgeInset + root.autoHideOffset : 0
        right: root.rightSide ? root.edgeInset + root.autoHideOffset : 0
    }

    Bar.BarGlassSegmentPublisher {
        vertical: true
        targetScreen: root.targetScreen
        segmentKey: root.unifiedSegmentKey
        active: root.surfaceActive
        position: root.surfaceY
        extent: root.surfaceHeight
        startRadius: root.startRadius
        endRadius: root.endRadius
    }

    // Visual-only group surface. Input remains on the existing vertical bar.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        anchors.fill: parent
        color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
        topLeftRadius: root.startRadius
        topRightRadius: root.startRadius
        bottomLeftRadius: root.endRadius
        bottomRightRadius: root.endRadius
        antialiasing: true
    }
}
