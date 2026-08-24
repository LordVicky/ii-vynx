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
        const panel = plugin("panel")
        if (panel)
            panel.controller = root
        const apps = plugin("apps")
        if (apps)
            apps.controller = root
        publishActivePlugin()
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

    function hoverEntered(screenName) {
        hoverClearTimer.stop()
        pluginHoverExitTimer.stop()

        const newHoverSession = !IslandState.hovered
        if (!activePlugin || activePlugin.name === "idle")
            IslandState.requestScreen(screenName)

        // A geometry-driven re-entry during the 240ms exit grace is still the
        // same pointer session. Only a real completed exit rearms Clock/Player.
        if (newHoverSession)
            passiveHoverAllowed = isAmbientPlugin(activePlugin)
        IslandState.hovered = true
    }

    function hoverExited() {
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
        IslandState.resetHostPublication()
    }
}