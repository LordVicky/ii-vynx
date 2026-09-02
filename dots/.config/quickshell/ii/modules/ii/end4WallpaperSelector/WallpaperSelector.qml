import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool reallyOpen: false

    Connections {
        target: GlobalStates
        function onEnd4WallpaperSelectorOpenChanged() {
            if (GlobalStates.end4WallpaperSelectorOpen) {
                closeAnimTimer.stop();
                root.reallyOpen = true;
            } else {
                closeAnimTimer.restart();
            }
        }
    }

    Timer {
        id: closeAnimTimer
        interval: Appearance.animation.elementMoveExit.duration
        onTriggered: root.reallyOpen = false
    }

    Loader {
        id: wallpaperSelectorLoader
        active: root.reallyOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            property bool monitorIsFocused: Hyprland.focusedMonitor?.id == monitor?.id

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:end4WallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors.top: true
            margins {
                top: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: content
            }

            implicitHeight: Appearance.sizes.wallpaperSelectorHeight
            implicitWidth: Appearance.sizes.wallpaperSelectorWidth

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(panelWindow);
                if (!KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
                content.slideIn();
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.end4WallpaperSelectorOpen = false;
                }
            }

            WallpaperSelectorContent {
                id: content
                width: parent.width
                height: parent.height
                x: 0
                y: 0

                function slideIn() {
                    content.y = -content.height;
                    Qt.callLater(() => { content.y = 0; });
                }

                Connections {
                    target: GlobalStates
                    function onEnd4WallpaperSelectorOpenChanged() {
                        if (!GlobalStates.end4WallpaperSelectorOpen) {
                            content.y = -content.height;
                        }
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: GlobalStates.end4WallpaperSelectorOpen
                            ? Appearance.animation.elementMoveEnter.duration
                            : Appearance.animation.elementMoveExit.duration
                        easing.type: GlobalStates.end4WallpaperSelectorOpen
                            ? Appearance.animation.elementMoveEnter.type
                            : Appearance.animation.elementMoveExit.type
                        easing.bezierCurve: GlobalStates.end4WallpaperSelectorOpen
                            ? Appearance.animation.elementMoveEnter.bezierCurve
                            : Appearance.animation.elementMoveExit.bezierCurve
                    }
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options.end4WallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        GlobalStates.end4WallpaperSelectorOpen = !GlobalStates.end4WallpaperSelectorOpen
    }

    IpcHandler {
        target: "end4WallpaperSelector"

        function open(): void {
            GlobalStates.end4WallpaperSelectorOpen = true;
        }

        function close(): void {
            GlobalStates.end4WallpaperSelectorOpen = false;
        }

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    GlobalShortcut {
        name: "end4WallpaperSelectorToggle"
        description: "Toggle End4 wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    GlobalShortcut {
        name: "end4WallpaperSelectorRandom"
        description: "Select random wallpaper from the End4 picker folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder();
        }
    }
}
