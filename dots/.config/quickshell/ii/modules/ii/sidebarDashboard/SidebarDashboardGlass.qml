import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

PanelWindow {
    id: root

    required property bool isOnRight
    required property bool surfaceActive
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property real topInset: 0
    property real bottomInset: 0

    visible: root.surfaceActive && GlobalStates.sidebarRightOpen
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    implicitWidth: root.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin

    WlrLayershell.namespace: "quickshell:sidebar-dashboard-glass"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        bottom: true
        left: !root.isOnRight
        right: root.isOnRight
    }

    margins {
        top: Appearance.sizes.hyprlandGapsOut + root.topInset
        bottom: Appearance.sizes.hyprlandGapsOut + root.bottomInset
        left: root.isOnRight ? 0 : Appearance.sizes.hyprlandGapsOut
        right: root.isOnRight ? Appearance.sizes.hyprlandGapsOut : 0
    }

    // Visual-only surface. Pointer and keyboard handling stay on the existing
    // interactive dashboard window so glass cannot intercept sidebar input.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        anchors.fill: parent
        color: RuntimeServices.liquidGlass?.surfaceColor ?? "transparent"
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        antialiasing: true
    }
}
