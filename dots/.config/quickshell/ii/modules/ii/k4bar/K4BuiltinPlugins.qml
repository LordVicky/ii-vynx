import QtQuick
import qs.modules.common

// Static built-in registry. Concrete plugin objects stay declaratively owned
// by this registry while the controller arbitrates which one is visible.
QtObject {
    id: root

    // Passive Clock/Player hover belongs to a pointer session. The controller
    // can latch it off while an explicitly opened utility owns the island so
    // closing that utility does not immediately rebound through Clock/Player.
    property bool passiveHoverAllowed: false

    readonly property list<QtObject> plugins: [
        volumePlugin, clockPlugin, playerPlugin, toastPlugin, panelPlugin,
        appsPlugin, settingsPlugin, launcherPlugin, clipboardPlugin, filesPlugin,
        windowsPlugin, systemPlugin, sessionPlugin, keysPlugin, weatherPlugin,
        capturePlugin, displaysPlugin, trayPlugin
    ]

    property bool playerHoverSession: false
    property var playerSessionMediaConnections: Connections {
        target: K4Media
        function onIsPlayingChanged() { if (IslandState.hovered && K4Media.isPlaying) root.playerHoverSession = true }
        function onHasPlayerChanged() { if (!K4Media.hasPlayer) root.playerHoverSession = false }
    }
    property var playerSessionHoverConnections: Connections {
        target: IslandState
        function onHoveredChanged() {
            if (!IslandState.hovered) root.playerHoverSession = false
            else if (K4Media.isPlaying) root.playerHoverSession = true
        }
    }

    property QtObject volumePlugin: K4Plugin {
        name: "volume"; title: "Volume"; priority: 40
        active: enabled && K4Audio.overlayOpen
        islandWidth: 240; islandHeight: 40
        view: Component { K4VolumeView {} }
    }
    property QtObject clockPlugin: K4Plugin {
        id: clockPluginObject
        name: "clock"; title: "Clock"; priority: 50
        active: enabled && IslandState.hovered && root.passiveHoverAllowed

        // K4 v1.0 measures the three Clock zones in the view and feeds them
        // back into this stable plugin object. Estimates are only first-frame
        // fallbacks while the view has not published real implicit widths yet.
        property int leftMeasured: 0
        property int centerMeasured: 0
        property int rightMeasured: 0

        readonly property int trayEstimate: K4Tray.count > 0
            ? Math.min(K4Tray.count, 5) * 28 + (K4Tray.count > 5 ? 28 : 0)
            : 0
        readonly property bool recordingActive: Persistent.states.screenRecord.active
        readonly property int rightEstimate: trayEstimate
            + (recordingActive ? 60 : 0)
            + (trayEstimate > 0 && recordingActive ? 6 : 0)

        readonly property int leftWidth: leftMeasured > 0 ? leftMeasured : 96
        readonly property int centerWidth: centerMeasured > 0
            ? centerMeasured : 92
        readonly property int rightRaw: rightMeasured > 0
            ? rightMeasured : rightEstimate
        readonly property int rightWidth: Math.min(rightRaw, 480)
        readonly property int zoneGap: 24

        islandWidth: 44 + leftWidth + zoneGap + centerWidth + zoneGap + rightWidth
        readonly property int notificationStripHeight: K4Settings.notificationsOnHover
            ? K4Notifications.stripHeight(3) : 0
        islandHeight: 68 + (notificationStripHeight > 0 ? notificationStripHeight + 18 : 0)
        view: Component {
            K4ClockView {
                trayPlugin: root.trayPlugin
                Binding {
                    target: clockPluginObject
                    property: "leftMeasured"
                    value: measuredLeft
                }
                Binding {
                    target: clockPluginObject
                    property: "centerMeasured"
                    value: measuredCenter
                }
                Binding {
                    target: clockPluginObject
                    property: "rightMeasured"
                    value: measuredRight
                }
            }
        }
    }
    property QtObject playerPlugin: K4Plugin {
        id: playerPluginObject
        name: "player"; title: "Player"; priority: 55

        // Track-change peek follows upstream v1.0.0's proven MPRIS settling
        // behavior: title/artist may arrive separately, so compare only after
        // 350 ms and never treat initial discovery or player shutdown as a new
        // track. Peek remains independent of isPlaying because some players
        // transiently report stopped while switching tracks.
        property bool trackPeekOpen: false
        property string previousTrackKey: ""
        readonly property string trackKey: K4Media.hasPlayer
                && String(K4Media.activePlayer?.trackTitle ?? "").length > 0
            ? String(K4Media.activePlayer.trackTitle) + " · "
                + String(K4Media.activePlayer?.trackArtist ?? "")
            : ""

        onTrackKeyChanged: trackSettleTimer.restart()

        Timer {
            id: trackSettleTimer
            interval: 350
            onTriggered: {
                const previous = playerPluginObject.previousTrackKey
                playerPluginObject.previousTrackKey = playerPluginObject.trackKey
                if (!K4Settings.playerPeekOnTrackChange || !playerPluginObject.enabled)
                    return
                if (playerPluginObject.trackKey.length === 0
                        || previous.length === 0
                        || previous === playerPluginObject.trackKey)
                    return
                playerPluginObject.trackPeekOpen = true
                trackPeekTimer.restart()
            }
        }

        Timer {
            id: trackPeekTimer
            interval: 3200
            onTriggered: playerPluginObject.trackPeekOpen = false
        }

        Connections {
            target: playerPluginObject
            function onEnabledChanged() {
                if (playerPluginObject.enabled)
                    return
                trackPeekTimer.stop()
                playerPluginObject.trackPeekOpen = false
            }
        }

        active: enabled && (
            (IslandState.hovered && root.passiveHoverAllowed
                && K4Media.hasPlayer
                && (K4Media.isPlaying || root.playerHoverSession))
            || trackPeekOpen
        )
        islandWidth: 340
        readonly property int notificationStripHeight: K4Settings.notificationsOnHover
            ? K4Notifications.stripHeight(3) : 0
        islandHeight: (K4Media.hasTimeline ? 140 : 115) + (notificationStripHeight > 0 ? notificationStripHeight + 15 : 0)

        function close() { trackPeekOpen = false }

        view: Component { K4PlayerView {} }
    }
    property QtObject toastPlugin: K4Plugin {
        name: "toast"; title: "Notification"; priority: 59; transitorio: true
        active: enabled && K4Notifications.toastOpen && !K4Notifications.inBand
        islandWidth: 440
        islandHeight: K4Notifications.buttons(K4Notifications.latest).length > 0 ? 112 : 96
        handlesBackgroundTap: true
        onBackgroundTapped: { K4Notifications.activate(K4Notifications.latest); K4Notifications.dismissToast() }
        function close() { K4Notifications.dismissToast() }
        view: Component { K4ToastView {} }
    }

    property QtObject panelPlugin: K4PanelPlugin {}
    property QtObject appsPlugin: K4AppsPlugin {}
    property QtObject settingsPlugin: K4SettingsPlugin {}
    property QtObject launcherPlugin: K4LauncherPlugin {}
    property QtObject clipboardPlugin: K4ClipboardPlugin {}
    property QtObject filesPlugin: K4FilesPlugin {}
    property QtObject windowsPlugin: K4WindowsPlugin {}
    property QtObject systemPlugin: K4SystemPlugin {}
    property QtObject sessionPlugin: K4SessionPlugin {}
    property QtObject keysPlugin: K4KeysPlugin {}
    property QtObject weatherPlugin: K4WeatherPlugin {}
    property QtObject capturePlugin: K4CapturePlugin {}
    property QtObject displaysPlugin: K4DisplaysPlugin {}
    property QtObject trayPlugin: K4TrayPlugin {}
}
