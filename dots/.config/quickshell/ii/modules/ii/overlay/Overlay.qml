import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property bool policyEnabled: Config.options.policies.overlay

    property Component regionComponent: Component {
        Region {}
    }

    function toggleOverlay() {
        if (!root.policyEnabled) {
            GlobalStates.overlayOpen = false;
            return;
        }
        GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
    }

    function releaseRuntimeState() {
        GlobalStates.overlayOpen = false;
        OverlayContext.clickableWidgets = [];
    }

    Connections {
        target: Config.options.policies
        function onOverlayChanged() {
            if (!root.policyEnabled)
                root.releaseRuntimeState();
        }
    }

    Component.onDestruction: root.releaseRuntimeState()
    
    Loader {
        id: overlayLoader
        active: root.policyEnabled && (GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets)
        sourceComponent: PanelWindow {
            id: overlayWindow
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            // Use OnDemand for pinned widgets to allow focus switching with mouse clicks
            WlrLayershell.keyboardFocus: GlobalStates.overlayOpen ? WlrKeyboardFocus.Exclusive : (OverlayContext.clickableWidgets.length > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
            visible: true
            color: "transparent"

            mask: Region {
                item: GlobalStates.overlayOpen ? overlayContent : null
                regions: OverlayContext.clickableWidgets.map((widget) => regionComponent.createObject(this, {
                    item: widget
                }));
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            HyprlandFocusGrab {
                id: grab
                windows: [overlayWindow]
                active: false
                onCleared: () => {
                    if (!active) GlobalStates.overlayOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverlayOpenChanged() {
                    delayedGrabTimer.restart();
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Appearance.animation.elementMoveFast.duration
                onTriggered: {
                    grab.active = GlobalStates.overlayOpen;
                }
            }

            OverlayContent {
                id: overlayContent
                anchors.fill: parent
            }
        }
    }

    IpcHandler {
        target: "overlay"

        function toggle(): void {
            root.toggleOverlay();
        }
    }

    GlobalShortcut {
        name: "overlayToggle"
        description: "Toggles overlay on press"

        onPressed: root.toggleOverlay()
    }
}
