import QtQuick
import qs.modules.common

// Static built-in registry. Concrete plugin objects stay declaratively owned
// by this registry while the controller arbitrates which one is visible.
QtObject {
    id: root

    // Passive Clock hover belongs to a generic pointer session. Player hover is
    // targeted separately from the idle media region so disabling generic idle
    // expansion does not also disable the media preview.
    property bool passiveHoverAllowed: false
    property bool clockHoverReady: false

    readonly property list<QtObject> plugins: [
        volumePlugin, clockPlugin, playerPlugin, toastPlugin, panelPlugin,
        appsPlugin, settingsPlugin, launcherPlugin, clipboardPlugin, filesPlugin,
        windowsPlugin, systemPlugin, sessionPlugin, keysPlugin, weatherPlugin,
        capturePlugin, displaysPlugin, trayPlugin
    ]

    // Give the targeted media region one short intent window before generic
    // Clock expansion can replace the idle pill. Keep the Timer behind an
    // explicit property because this registry is a bare QtObject and has no
    // default child property.
    property var clockHoverIntentTimer: Timer {
        id: clockHoverIntent
        interval: 140
        onTriggered: {
            if (IslandState.hovered && root.passiveHoverAllowed
                    && !root.playerHoverSession && !IslandState.mediaHovered)
                root.clockHoverReady = true
        }
    }

    onPassiveHoverAllowedChanged: {
        if (!root.passiveHoverAllowed) {
            clockHoverIntent.stop()
            root.clockHoverReady = false
            return
        }
        if (IslandState.hovered && !root.playerHoverSession
                && !IslandState.mediaHovered) {
            root.clockHoverReady = false
            clockHoverIntent.restart()
        }
    }

    // Player preview is armed only by the media sub-region in the collapsed
    // idle pill. Once armed, keep it latched for the rest of the island hover
    // session so the idle -> player geometry transition cannot immediately
    // cancel itself when the collapsed media widget disappears.
    property bool playerHoverSession: false
    property var playerSessionMediaConnections: Connections {
        target: K4Media
        function onHasPlayerChanged() {
            if (!K4Media.hasPlayer)
                root.playerHoverSession = false
        }
    }
    property var playerSessionHoverConnections: Connections {
        target: IslandState
        function onMediaHoveredChanged() {
            if (!IslandState.mediaHovered || !K4Media.isPlaying)
                return
            clockHoverIntent.stop()
            root.clockHoverReady = false
            root.playerHoverSession = true
        }
        function onHoveredChanged() {
            if (!IslandState.hovered) {
                clockHoverIntent.stop()
                root.clockHoverReady = false
                root.playerHoverSession = false
                return
            }
            root.clockHoverReady = false
            if (root.passiveHoverAllowed && !IslandState.mediaHovered
                    && !root.playerHoverSession)
                clockHoverIntent.restart()
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
            && root.clockHoverReady && !root.playerHoverSession

        // Clock keeps its time at the island center. Measure the three zones,
        // mirror the larger side reserve, and let widthScale add extra room on top.
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
        readonly property int sideWidth: Math.max(leftWidth, rightWidth)
        readonly property int zoneGap: 24

        islandWidth: 44 + centerWidth + 2 * (sideWidth + zoneGap)
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
            (IslandState.hovered && K4Media.hasPlayer
                && root.playerHoverSession)
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
        readonly property bool expanded: IslandState.hovered
        readonly property bool hasImage: K4Notifications.hasImage(K4Notifications.latest)
        readonly property var buttons: K4Notifications.buttons(K4Notifications.latest)
        islandWidth: expanded ? (hasImage ? 520 : 500) : 382
        // Expanded notification geometry stays dense enough that short messages
        // do not leave a large empty lower half. Image/action variants reserve
        // only the extra height their visible content needs.
        islandHeight: !expanded ? 54
            : hasImage && buttons.length > 0 ? 180
            : hasImage ? 136
            : buttons.length > 0 ? 148 : 120
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
