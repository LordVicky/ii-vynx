import QtQuick

// Host arbitration adapted from k4ditano/k4 shell.qml at the pinned source
// commit. Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
QtObject {
    id: root

    property list<QtObject> plugins
    property bool passiveHoverAllowed: false
    property QtObject builtins: K4BuiltinPlugins {
        passiveHoverAllowed: root.passiveHoverAllowed
    }

    function attachBuiltins() {
        const combined = []
        for (let i = 0; i < plugins.length; ++i)
            combined.push(plugins[i])
        for (let i = 0; i < builtins.plugins.length; ++i)
            combined.push(builtins.plugins[i])
        plugins = combined
    }

    function plugin(name) {
        for (let i = 0; i < plugins.length; ++i) {
            if (plugins[i]?.name === name)
                return plugins[i]
        }
        return null
    }

    function isProtectedPlugin(candidate) {
        return !candidate || candidate.name === "idle" || candidate.name === "settings"
            || candidate.name.startsWith("demo-") || candidate.configurable === false
    }

    function configurablePlugins() {
        const result = []
        for (let i = 0; i < plugins.length; ++i) {
            const candidate = plugins[i]
            if (isProtectedPlugin(candidate))
                continue
            result.push(candidate)
        }
        return result
    }

    function applyPluginEnabled(candidate, wanted) {
        if (!candidate)
            return
        const target = Boolean(wanted)
        // K4-11 will destroy/recreate disabled plugins. Until then, clear any
        // stale open state accumulated while a static plugin was disabled before
        // making it eligible to participate again.
        if (target && !candidate.enabled && candidate.closeOnDisable
                && typeof candidate.close === "function")
            candidate.close()
        candidate.enabled = target
    }

    function applyPersistedEnablement() {
        const configurable = configurablePlugins()
        for (let i = 0; i < configurable.length; ++i) {
            const candidate = configurable[i]
            applyPluginEnabled(candidate, K4Settings.pluginEnabled(candidate.name))
        }
    }

    function setPluginEnabled(name, wanted) {
        const candidate = plugin(name)
        if (isProtectedPlugin(candidate))
            return false
        const target = Boolean(wanted)
        K4Settings.setPluginEnabled(name, target)
        applyPluginEnabled(candidate, target)
        return true
    }

    // Apps is a view over this registry, never a second catalog owner. Only
    // plugins that explicitly opt into the application contract appear.
    function applicationPlugins() {
        const result = []
        for (let i = 0; i < plugins.length; ++i) {
            const candidate = plugins[i]
            if (candidate && candidate.name !== "apps" && candidate.application === true)
                result.push(candidate)
        }
        return result
    }

    function openApplication(name) {
        const target = plugin(name)
        if (!target || !target.enabled || target.application !== true
                || typeof target.openApplication !== "function")
            return false
        return target.openApplication() !== false
    }

    readonly property var idlePlugin: plugin("idle")

    // Highest-priority enabled active plugin wins. Idle is a normal priority-0
    // plugin so it naturally becomes the fallback.
    readonly property var activePlugin: {
        let best = null
        for (let i = 0; i < plugins.length; ++i) {
            const candidate = plugins[i]
            if (!candidate || !candidate.enabled || !candidate.active)
                continue
            if (best === null || candidate.priority > best.priority)
                best = candidate
        }
        return best
    }

    function isPassiveHoverPlugin(candidate) {
        return candidate === builtins.clockPlugin || candidate === builtins.playerPlugin
    }

    // Idle, passive hover owners, volume and transient notifications may hand
    // control back to Clock/Player in the same pointer session. Explicitly
    // opened utilities may not: otherwise closing one while still hovered makes
    // the island expand to Clock/Player before the next click can open Panel.
    function isAmbientPlugin(candidate) {
        return !candidate || candidate === idlePlugin
            || candidate === builtins.volumePlugin
            || candidate.transitorio
            || isPassiveHoverPlugin(candidate)
    }

    // activePlugin depends on Clock/Player.active, which in turn depends on the
    // passive-hover latch. Writing that latch synchronously from
    // onActivePluginChanged creates a QML binding loop. Defer the write until
    // the current binding evaluation has settled, then confirm the explicit
    // owner is still current before consuming the hover session.
    function schedulePassiveHoverSuppression() {
        if (!activePlugin || isAmbientPlugin(activePlugin))
            return
        Qt.callLater(function() {
            const winner = root.activePlugin
            if (winner && !root.isAmbientPlugin(winner))
                root.passiveHoverAllowed = false
        })
    }

    function dismissTransients() {
        const winner = activePlugin
        if (!winner || winner.transitorio)
            return

        for (let i = 0; i < plugins.length; ++i) {
            const candidate = plugins[i]
            if (!candidate || candidate === winner
                    || !candidate.transitorio || !candidate.active)
                continue
            if (typeof candidate.close === "function")
                candidate.close()
        }
    }

    function publishActivePlugin() {
        dismissTransients()
        schedulePassiveHoverSuppression()

        const previous = IslandState.occupant
        if (activePlugin && activePlugin.name !== "idle") {
            if (IslandState.requestedScreen.length > 0
                    || previous.length === 0 || previous === "idle")
                IslandState.activeScreen = IslandState.takeRequestedScreen()
        } else {
            IslandState.requestedScreen = ""
        }

        IslandState.occupant = activePlugin?.name ?? ""
        IslandState.open = activePlugin !== null
            && activePlugin.name !== "idle"
            && activePlugin.islandHeight > K4Theme.baseHeight
    }

    onActivePluginChanged: publishActivePlugin()
    Component.onCompleted: {
        attachBuiltins()
        applyPersistedEnablement()
        const panel = plugin("panel")
        if (panel)
            panel.controller = root
        const apps = plugin("apps")
        if (apps)
            apps.controller = root
        const settings = plugin("settings")
        if (settings)
            settings.controller = root
        publishActivePlugin()
    }

    property var settingsConnections: Connections {
        target: K4Settings
        function onDisabledPluginsChanged() {
            root.applyPersistedEnablement()
        }
    }

    function visiblePluginFor(screenName) {
        const winner = activePlugin
        if (!winner)
            return idlePlugin
        if (winner.name === "idle")
            return winner
        return screenName === IslandState.activeScreen ? winner : idlePlugin
    }

    function closeVisiblePlugin(screenName) {
        const visible = visiblePluginFor(screenName)
        if (visible && visible.name !== "idle" && typeof visible.close === "function")
            visible.close()
    }

    // Pinned k4 treats an unhandled island-background click as the global
    // Control Center affordance. Preserve the clicked monitor as the requested
    // owner before opening Panel so publishActivePlugin routes it there.
    function backgroundTap(screenName) {
        const visible = visiblePluginFor(screenName)
        if (visible && visible.name !== "idle" && visible.handlesBackgroundTap) {
            visible.backgroundTapped()
            return true
        }

        const panel = plugin("panel")
        if (!panel || !panel.enabled)
            return false

        IslandState.requestScreen(screenName)
        panel.openTab("controls")
        return true
    }

    // Stop pending hover teardown without opening a new hover session. Hidden
    // mode uses this while its edge peek is returning; Clock/Player still wait
    // for the host's deliberate dwell before IslandState.hovered becomes true.
    function holdHoverExit() {
        hoverClearTimer.stop()
        pluginHoverExitTimer.stop()
    }

    function hoverEntered(screenName) {
        holdHoverExit()

        const newHoverSession = !IslandState.hovered
        if (!activePlugin || activePlugin.name === "idle")
            IslandState.requestScreen(screenName)

        // A geometry-driven re-entry during the current exit grace is still the
        // same pointer session. Only a real completed exit rearms Clock/Player.
        if (newHoverSession)
            passiveHoverAllowed = isAmbientPlugin(activePlugin)
        IslandState.hovered = true
    }

    // Bottom layer-surface growth can briefly move the Wayland surface origin
    // while a passive Player/Clock view expands. Preserve the same pointer
    // session through the full geometry animation so a synthetic leave/re-entry
    // cannot reset Player and then reopen Clock underneath it. Top placement and
    // non-passive owners retain the established 240 ms exit grace.
    function hoverExitGraceMs() {
        return K4Settings.position === "bottom" && isPassiveHoverPlugin(activePlugin)
            ? 520 : 240
    }

    function hoverExited() {
        hoverClearTimer.interval = hoverExitGraceMs()
        hoverClearTimer.restart()
        armPluginHoverExit()
    }

    function armPluginHoverExit() {
        const winner = activePlugin
        if (!winner || !winner.closeOnHoverExit)
            return
        pluginHoverExitTimer.interval = winner.hoverExitDelay
        pluginHoverExitTimer.restart()
    }

    property var hoverClearTimer: Timer {
        interval: 240
        onTriggered: {
            IslandState.hovered = false
            root.passiveHoverAllowed = false
        }
    }

    property var pluginHoverExitTimer: Timer {
        interval: 700
        onTriggered: {
            const winner = root.activePlugin
            if (winner?.closeOnHoverExit)
                winner.hoverTimedOut()
        }
    }

    function reset() {
        hoverClearTimer.stop()
        pluginHoverExitTimer.stop()
        passiveHoverAllowed = false
        const panel = plugin("panel")
        if (panel?.controller === root)
            panel.controller = null
        const apps = plugin("apps")
        if (apps?.controller === root)
            apps.controller = null
        const settings = plugin("settings")
        if (settings?.controller === root)
            settings.controller = null
        IslandState.resetHostPublication()
    }
}
