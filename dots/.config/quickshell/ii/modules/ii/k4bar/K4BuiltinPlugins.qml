import QtQuick
import qs.modules.common

// Static built-in registry for the parity slices before K4-11 replaces this
// with k4-style dynamic plugin discovery/loading.
QtObject {
    id: root

    readonly property list<QtObject> plugins: [
        volumePlugin,
        clockPlugin,
        playerPlugin,
        toastPlugin,
        panelPlugin
    ]

    // Pinned k4 dismisses Player as soon as playback pauses, which also removes
    // the Player's own Resume control. Preserve the upstream paused-hover default
    // (Clock), but keep an already-open Player alive for the current hover.
    property bool playerHoverSession: false

    property var playerSessionMediaConnections: Connections {
        target: K4Media

        function onIsPlayingChanged() {
            if (IslandState.hovered && K4Media.isPlaying)
                root.playerHoverSession = true
        }

        function onHasPlayerChanged() {
            if (!K4Media.hasPlayer)
                root.playerHoverSession = false
        }
    }

    property var playerSessionHoverConnections: Connections {
        target: IslandState

        function onHoveredChanged() {
            if (!IslandState.hovered)
                root.playerHoverSession = false
            else if (K4Media.isPlaying)
                root.playerHoverSession = true
        }
    }

    property QtObject volumePlugin: K4Plugin {
        name: "volume"
        title: "Volume"
        priority: 40
        active: enabled && K4Audio.overlayOpen
        islandWidth: 240
        islandHeight: 40
        view: Component { K4VolumeView {} }
    }

    property QtObject clockPlugin: K4Plugin {
        name: "clock"
        title: "Clock"
        priority: 50
        active: enabled && IslandState.hovered
        islandWidth: Persistent.states.screenRecord.active ? 352 : 328
        readonly property int notificationStripHeight: K4Notifications.stripHeight(3)
        islandHeight: 68 + (notificationStripHeight > 0 ? notificationStripHeight + 18 : 0)
        view: Component { K4ClockView {} }
    }

    property QtObject playerPlugin: K4Plugin {
        name: "player"
        title: "Player"
        priority: 55
        active: enabled && IslandState.hovered && K4Media.hasPlayer
            && (K4Media.isPlaying || root.playerHoverSession)
        islandWidth: 340
        readonly property int notificationStripHeight: K4Notifications.stripHeight(3)
        islandHeight: (K4Media.hasTimeline ? 140 : 115)
            + (notificationStripHeight > 0 ? notificationStripHeight + 15 : 0)
        view: Component { K4PlayerView {} }
    }

    property QtObject toastPlugin: K4Plugin {
        name: "toast"
        title: "Notification"
        priority: 59
        transitorio: true
        active: enabled && K4Notifications.toastOpen && !K4Notifications.inBand
        islandWidth: 440
        islandHeight: K4Notifications.buttons(K4Notifications.latest).length > 0 ? 112 : 96
        handlesBackgroundTap: true

        onBackgroundTapped: {
            K4Notifications.activate(K4Notifications.latest)
            K4Notifications.dismissToast()
        }

        function close() {
            K4Notifications.dismissToast()
        }

        view: Component { K4ToastView {} }
    }

    property QtObject panelPlugin: K4PanelPlugin {}
}
