import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common

PanelWindow {
    id: root

    required property bool surfaceActive
    required property bool showBarBackground

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

    // This surface is visual only. The existing bar keeps all pointer, scroll,
    // hover and exclusive-zone behavior.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        anchors.fill: parent
        color: RuntimeServices.liquidGlass?.barSurfaceColor ?? "transparent"
    }
}
