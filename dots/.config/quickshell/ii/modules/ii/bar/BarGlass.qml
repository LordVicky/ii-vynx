import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

PanelWindow {
    id: root

    required property bool surfaceActive
    required property bool showBarBackground
    property var segments: []
    property real contentTopOffset: 0
    property real contentBottomOffset: 0
    readonly property real autoHideOffset: Number(GlobalStates.barAutoHideOffsets[root.screen?.name ?? ""] ?? 0)
    readonly property bool unifiedSegmentsVisible: GlobalStates.unifiedBarGlassSegmentsEnabled
        && !root.showBarBackground
        && root.segments.length > 0

    visible: root.surfaceActive && (root.showBarBackground || root.unifiedSegmentsVisible)
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitHeight: Appearance.sizes.baseBarHeight

    WlrLayershell.namespace: "quickshell:bar-glass"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        left: true
        right: true
        top: !Config.options.bar.bottom
        bottom: Config.options.bar.bottom
    }

    margins {
        left: root.unifiedSegmentsVisible ? 0 : Appearance.sizes.hyprlandGapsOut
        right: root.unifiedSegmentsVisible ? 0 : Appearance.sizes.hyprlandGapsOut
        top: Config.options.bar.bottom
            ? 0
            : (root.unifiedSegmentsVisible
                ? (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0) + root.autoHideOffset
                : Appearance.sizes.hyprlandGapsOut + root.contentTopOffset + root.autoHideOffset)
        bottom: Config.options.bar.bottom
            ? (root.unifiedSegmentsVisible
                ? (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0) + root.autoHideOffset
                : Appearance.sizes.hyprlandGapsOut + root.contentBottomOffset + root.autoHideOffset)
            : 0
    }

    onSegmentsChanged: {
        const keys = root.segments.map(segment => segment?.segmentKey ?? "<null>");
        console.log("[bar-glass-trace] model", keys.join(","));
    }

    // This window is visual only. All pointer, scroll and hover behavior stays
    // on quickshell:bar so splitting the glass surface cannot steal input.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        anchors.fill: parent
        visible: root.showBarBackground
        color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
        radius: height / 2
        antialiasing: true
    }

    Repeater {
        model: root.unifiedSegmentsVisible ? root.segments : []

        delegate: Rectangle {
            required property var modelData
            readonly property bool traceEnabled: modelData.segmentKey === "pill:weather"
                || modelData.segmentKey === "pill:music_player"

            function trace(reason) {
                if (!traceEnabled)
                    return;

                console.log(
                    "[bar-glass-trace]",
                    modelData.segmentKey,
                    reason,
                    "x=", x,
                    "width=", width,
                    "resolvedPosition=", modelData.resolvedPosition,
                    "resolvedExtent=", modelData.resolvedExtent,
                    "fallbackPosition=", modelData.position,
                    "fallbackExtent=", modelData.extent,
                    "direct=", modelData.usesDirectGeometry,
                    "sourceX=", modelData.sourceItem?.x,
                    "sourceWidth=", modelData.sourceItem?.width
                );
            }

            x: Math.round(modelData.resolvedPosition)
            y: 4
            width: Math.max(1, modelData.resolvedExtent)
            height: Math.max(1, root.height - 8)
            color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
            topLeftRadius: modelData.startRadius
            bottomLeftRadius: modelData.startRadius
            topRightRadius: modelData.endRadius
            bottomRightRadius: modelData.endRadius
            antialiasing: true

            Component.onCompleted: trace("created")
            Component.onDestruction: trace("destroyed")
            onXChanged: trace("x-changed")
            onWidthChanged: trace("width-changed")

            Connections {
                target: modelData

                function onResolvedPositionChanged() {
                    trace("resolved-position-changed");
                }

                function onResolvedExtentChanged() {
                    trace("resolved-extent-changed");
                }
            }
        }
    }
}
