import QtQuick
import qs.modules.common

// Static built-in registry for the parity slices before K4-11 replaces this
// with k4-style dynamic plugin discovery/loading.
QtObject {
    id: root

    readonly property list<QtObject> plugins: [
        volumePlugin,
        clockPlugin,
        playerPlugin
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
        islandHeight: 68
        view: Component { K4ClockView {} }
    }

    property QtObject playerPlugin: K4Plugin {
        name: "player"
        title: "Player"
        priority: 55
        active: enabled && IslandState.hovered && K4Media.hasPlayer
            && (K4Media.isPlaying || root.playerHoverSession)
        islandWidth: 340
        islandHeight: K4Media.hasTimeline ? 140 : 115
        view: Component { K4PlayerView {} }
    }
}
