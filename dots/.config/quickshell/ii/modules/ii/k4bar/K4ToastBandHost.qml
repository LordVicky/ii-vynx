pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

// Compact notification band used while an explicit plugin owns the island.
// It shares the island card but never reserves compositor space or expands.
Scope {
    Variants {
        model: GlobalStates.screenLocked ? [] : Quickshell.screens

        delegate: PanelWindow {
            id: bandWindow
            required property var modelData
            screen: modelData

            readonly property bool bottom: Config.options.bar.k4.position === "bottom"
            readonly property var islandRect: IslandState.rects[bandWindow.screen.name] ?? null
            readonly property bool targetScreen: IslandState.activeScreen === bandWindow.screen.name
            readonly property bool shouldShow: K4Notifications.toastOpen && K4Notifications.inBand
                && targetScreen && islandRect !== null
            readonly property real desiredLeft: islandRect
                ? islandRect.x + islandRect.ancho / 2 - implicitWidth / 2 : 0

            anchors.top: !bottom
            anchors.bottom: bottom
            anchors.left: true

            margins.left: Math.max(8, Math.min(screen.width - implicitWidth - 8, desiredLeft))
            margins.top: !bottom && islandRect ? islandRect.y + islandRect.alto + 8 : 0
            margins.bottom: bottom && islandRect ? screen.height - islandRect.y + 8 : 0

            implicitWidth: 420
            implicitHeight: 54
            color: "transparent"
            focusable: false
            exclusionMode: ExclusionMode.Ignore
            visible: shouldShow
            mask: Region { item: band }

            WlrLayershell.namespace: "quickshell:k4bar-notification"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: band
                anchors.fill: parent
                radius: 16
                color: K4Theme.islandBg

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: K4Notifications.holdToast()
                    onExited: K4Notifications.resumeToast()
                    onClicked: mouse => {
                        mouse.accepted = true
                        K4Notifications.activate(K4Notifications.latest)
                        K4Notifications.dismissToast()
                    }
                }

                K4NotificationCard {
                    anchors.fill: parent
                    notification: K4Notifications.latest
                    expanded: false
                    bandMode: true

                    onDismissRequested: K4Notifications.dismissToast()
                    onActionRequested: action => {
                        K4Notifications.invokeAction(K4Notifications.latest, action)
                        K4Notifications.dismissToast()
                    }
                }
            }
        }
    }
}
