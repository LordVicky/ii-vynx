import QtQuick
import Quickshell.Io
import qs.modules.common

// Static built-in registry for the parity slices before K4-11 replaces this
// with declaratively managed built-ins. Managed proxies stay in this stable
// registry while Loader owns only their private implementation lifetime.
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

    function managedPlugin(name) {
        const id = String(name)
        for (let i = 0; i < plugins.length; ++i) {
            const candidate = plugins[i]
            if (candidate?.name === id && typeof candidate.retryLoad === "function")
                return candidate
        }
        return null
    }

    // Temporary K4-11 fault harness. It changes only a managed proxy's Loader
    // source/gate and never changes registry membership or QObject ownership.
    property var lifecycleDebugIpc: IpcHandler {
        target: "k4.pluginLifecycleDebug"

        function fail(name: string): void {
            const candidate = root.managedPlugin(name)
            if (candidate && typeof candidate.debugFailLoad === "function")
                candidate.debugFailLoad()
        }

        function restore(name: string): void {
            const candidate = root.managedPlugin(name)
            if (candidate && typeof candidate.debugRestoreLoad === "function")
                candidate.debugRestoreLoad()
        }

        function retry(name: string): void {
            const candidate = root.managedPlugin(name)
            if (candidate)
                candidate.retryLoad()
        }

        function status(name: string): string {
            const candidate = root.managedPlugin(name)
            if (!candidate)
                return JSON.stringify({ id: String(name), found: false })
            return JSON.stringify({
                id: candidate.name,
                found: true,
                enabled: candidate.enabled,
                requestedEnabled: candidate.requestedEnabled,
                loaded: candidate.instantiated,
                error: candidate.loadError,
                faulted: candidate.debugLoadFailure,
                retryGate: candidate.retryGate
            })
        }
    }

    property QtObject volumePlugin: K4Plugin {
        name: "volume"; title: "Volume"; priority: 40
        closeOnDisable: false
        active: enabled && K4Audio.overlayOpen
        islandWidth: 240; islandHeight: 40
        view: Component { K4VolumeView {} }
    }
    property QtObject clockPlugin: K4Plugin {
        name: "clock"; title: "Clock"; priority: 50
        closeOnDisable: false
        active: enabled && IslandState.hovered && root.passiveHoverAllowed
        readonly property int traySide: K4Tray.count > 0
            ? Math.min(K4Tray.count, 5) * 24 + 56 : 48
        islandWidth: Math.max(Persistent.states.screenRecord.active ? 352 : 328,
            136 + 2 * Math.max(96, traySide))
        readonly property int notificationStripHeight: K4Settings.notificationsOnHover
            ? K4Notifications.stripHeight(3) : 0
        islandHeight: 68 + (notificationStripHeight > 0 ? notificationStripHeight + 18 : 0)
        view: Component { K4ClockView { trayPlugin: root.trayPlugin } }
    }
    property QtObject playerPlugin: K4Plugin {
        id: playerPluginObject
        name: "player"; title: "Player"; priority: 55
        closeOnDisable: false

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
    property QtObject windowsPlugin: K4ManagedPlugin {
        name: "windows"
        title: "Windows"
        application: true
        applicationGlyph: String.fromCodePoint(0xF05B2)
        source: Qt.resolvedUrl("K4WindowsPlugin.qml")
    }
    property QtObject systemPlugin: K4ManagedPlugin {
        name: "system"
        title: "System"
        application: true
        applicationGlyph: String.fromCodePoint(0xF04BC)
        source: Qt.resolvedUrl("K4SystemPlugin.qml")
    }
    property QtObject sessionPlugin: K4ManagedPlugin {
        name: "session"
        title: "Session"
        application: true
        applicationGlyph: String.fromCodePoint(0xF0425)
        source: Qt.resolvedUrl("K4SessionPlugin.qml")
    }
    property QtObject keysPlugin: K4ManagedPlugin {
        name: "keys"
        title: "Shortcuts"
        application: true
        applicationGlyph: String.fromCodePoint(0xF030C)
        source: Qt.resolvedUrl("K4KeysPlugin.qml")
    }
    property QtObject weatherPlugin: K4WeatherPlugin {}
    property QtObject capturePlugin: K4CapturePlugin {}
    property QtObject displaysPlugin: K4ManagedPlugin {
        name: "displays"
        title: "Displays"
        application: true
        applicationGlyph: String.fromCodePoint(0xF037A)
        source: Qt.resolvedUrl("K4DisplaysPlugin.qml")
    }
    property QtObject trayPlugin: K4TrayPlugin {}
}
