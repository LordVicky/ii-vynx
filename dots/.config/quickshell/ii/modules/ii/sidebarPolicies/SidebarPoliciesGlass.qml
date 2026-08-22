import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

PanelWindow {
    id: root

    required property bool isOnLeft
    required property bool surfaceActive
    required property real sidebarWidth

    visible: root.surfaceActive && GlobalStates.sidebarLeftOpen
    exclusionMode: ExclusionMode.Normal
    focusable: false
    color: "transparent"
    implicitWidth: Appearance.sizes.sidebarWidthExtended + Appearance.sizes.elevationMargin

    WlrLayershell.namespace: root.isOnLeft
        ? "quickshell:sidebar-policies-glass-left"
        : "quickshell:sidebar-policies-glass-right"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        bottom: true
        left: root.isOnLeft
        right: !root.isOnLeft
    }

    // Visual-only surface. Pointer and keyboard handling stay on the existing
    // policy PanelWindow so this layer cannot intercept sidebar input.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        id: surfaceVisual

        y: Appearance.sizes.hyprlandGapsOut
        height: parent.height - (Appearance.sizes.hyprlandGapsOut * 2)
        width: root.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
        color: RuntimeServices.liquidGlass?.surfaceColor ?? "transparent"
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        antialiasing: true

        Behavior on width {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        Behavior on anchors.leftMargin {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on anchors.rightMargin {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        state: root.isOnLeft ? "left" : "right"
        states: [
            State {
                name: "left"
                AnchorChanges {
                    target: surfaceVisual
                    anchors.left: parent.left
                    anchors.right: undefined
                }
                PropertyChanges {
                    target: surfaceVisual
                    anchors.leftMargin: Appearance.sizes.hyprlandGapsOut
                    anchors.rightMargin: 0
                }
            },
            State {
                name: "right"
                AnchorChanges {
                    target: surfaceVisual
                    anchors.left: undefined
                    anchors.right: parent.right
                }
                PropertyChanges {
                    target: surfaceVisual
                    anchors.rightMargin: Appearance.sizes.hyprlandGapsOut
                    anchors.leftMargin: 0
                }
            }
        ]
    }
}
