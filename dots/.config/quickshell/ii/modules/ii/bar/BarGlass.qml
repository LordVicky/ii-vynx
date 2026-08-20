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
    property real contentTopOffset: 0
    property real contentBottomOffset: 0
    readonly property real autoHideOffset: Number(GlobalStates.barAutoHideOffsets[root.screen?.name ?? ""] ?? 0)

    visible: root.surfaceActive && root.showBarBackground
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
        left: Appearance.sizes.hyprlandGapsOut
        right: Appearance.sizes.hyprlandGapsOut
        top: Config.options.bar.bottom
            ? 0
            : Appearance.sizes.hyprlandGapsOut + root.contentTopOffset + root.autoHideOffset
        bottom: Config.options.bar.bottom
            ? Appearance.sizes.hyprlandGapsOut + root.contentBottomOffset + root.autoHideOffset
            : 0
    }

    // This window is visual only. All pointer, scroll and hover behavior stays
    // on quickshell:bar so splitting the glass surface cannot steal input.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        anchors.fill: parent
        color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
        radius: height / 2
        antialiasing: true
    }
}
