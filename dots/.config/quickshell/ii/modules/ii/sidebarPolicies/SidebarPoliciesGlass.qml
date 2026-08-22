import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PanelWindow {
    id: root

    required property bool isOnLeft
    required property bool surfaceActive
    required property bool pinned
    required property real sidebarWidth
    property bool decoratorsActive: false

    readonly property var monitorData: HyprlandData.monitors.find(monitor => monitor.name === root.screen?.name) ?? null
    readonly property var reservedEdges: root.monitorData?.reserved ?? [0, 0, 0, 0]
    readonly property real policyExclusiveZone: root.pinned
        ? Math.max(0, root.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin)
        : 0
    readonly property real pinnedTopReserve: root.pinned ? root.reservedEdge(1) : 0
    readonly property real pinnedBottomReserve: root.pinned ? root.reservedEdge(3) : 0
    readonly property real pinnedLeftReserve: root.pinned ? root.externalSideReserve(0, root.isOnLeft) : 0
    readonly property real pinnedRightReserve: root.pinned ? root.externalSideReserve(2, !root.isOnLeft) : 0

    function reservedEdge(index) {
        const value = Number(root.reservedEdges?.[index] ?? 0);
        return isFinite(value) ? Math.max(0, value) : 0;
    }

    function externalSideReserve(index, ownsEdge) {
        const reserve = root.reservedEdge(index);
        if (!root.pinned || !ownsEdge || root.policyExclusiveZone <= 0)
            return reserve;

        // Hyprland's monitor reserve includes this policy panel once its positive
        // exclusive zone is committed. Before that update arrives, keep the old
        // external reserve rather than subtracting from a smaller stale value.
        return reserve >= root.policyExclusiveZone
            ? Math.max(0, reserve - root.policyExclusiveZone)
            : reserve;
    }

    function refreshPinnedReserves() {
        if (!root.pinned)
            return;
        HyprlandData.updateMonitors();
        reserveRefresh.restart();
    }

    onPinnedChanged: {
        if (!root.pinned) {
            root.decoratorsActive = false;
            return;
        }
        root.refreshPinnedReserves();
    }
    onSidebarWidthChanged: root.refreshPinnedReserves()
    onVisibleChanged: if (visible) root.refreshPinnedReserves()
    Component.onCompleted: root.refreshPinnedReserves()

    Timer {
        id: reserveRefresh
        interval: 120
        repeat: false
        onTriggered: HyprlandData.updateMonitors()
    }

    Timer {
        interval: 150
        repeat: false
        running: root.pinned && !root.decoratorsActive
        onTriggered: {
            if (root.pinned)
                root.decoratorsActive = true;
        }
    }

    visible: root.surfaceActive && GlobalStates.sidebarLeftOpen
    // A pinned policy panel owns a positive exclusive zone. Ignore that zone on
    // the visual-only layer and reproduce only the monitor's external reserves.
    exclusionMode: root.pinned ? ExclusionMode.Ignore : ExclusionMode.Normal
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

    margins {
        top: root.pinnedTopReserve
        bottom: root.pinnedBottomReserve
        left: root.isOnLeft ? root.pinnedLeftReserve : 0
        right: !root.isOnLeft ? root.pinnedRightReserve : 0
    }

    // Visual-only surface. Pointer and keyboard handling stay on the existing
    // policy PanelWindow so this layer cannot intercept sidebar input.
    mask: Region {
        width: 0
        height: 0
    }

    Rectangle {
        id: surfaceVisual

        y: root.pinned ? 0 : Appearance.sizes.hyprlandGapsOut
        height: root.pinned ? parent.height : parent.height - (Appearance.sizes.hyprlandGapsOut * 2)
        width: root.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
        color: RuntimeServices.liquidGlass?.surfaceColor ?? "transparent"
        radius: root.pinned ? 0 : Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        antialiasing: true
        property bool _initialized: false

        Timer {
            interval: 2500 // Match the policy foreground's first-show resize guard.
            running: true
            onTriggered: surfaceVisual._initialized = true
        }

        Behavior on height {
            enabled: surfaceVisual._initialized
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on y {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
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
                    anchors.leftMargin: root.pinned ? 0 : Appearance.sizes.hyprlandGapsOut
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
                    anchors.rightMargin: root.pinned ? 0 : Appearance.sizes.hyprlandGapsOut
                    anchors.leftMargin: 0
                }
            }
        ]
    }

    Loader {
        active: root.decoratorsActive
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: root.isOnLeft ? surfaceVisual.right : undefined
            right: !root.isOnLeft ? surfaceVisual.left : undefined
        }
        width: Appearance.rounding.screenRounding

        sourceComponent: Item {
            RoundCorner {
                anchors {
                    top: parent.top
                    left: root.isOnLeft ? parent.left : undefined
                    right: !root.isOnLeft ? parent.right : undefined
                }
                implicitSize: Appearance.rounding.screenRounding
                color: RuntimeServices.liquidGlass?.surfaceColor ?? "transparent"
                corner: root.isOnLeft ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.TopRight
            }
            RoundCorner {
                anchors {
                    bottom: parent.bottom
                    left: root.isOnLeft ? parent.left : undefined
                    right: !root.isOnLeft ? parent.right : undefined
                }
                implicitSize: Appearance.rounding.screenRounding
                color: RuntimeServices.liquidGlass?.surfaceColor ?? "transparent"
                corner: root.isOnLeft ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.BottomRight
            }
        }
    }
}
