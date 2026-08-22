import QtQuick

// Host arbitration adapted from k4ditano/k4 shell.qml at the pinned source
// commit. Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
QtObject {
    id: root

    property list<QtObject> plugins

    function plugin(name) {
        for (let i = 0; i < plugins.length; ++i) {
            if (plugins[i]?.name === name)
                return plugins[i]
        }
        return null
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

    function dismissTransients() {
        const winner = activePlugin
        if (!winner || winner.transient)
            return

        for (let i = 0; i < plugins.length; ++i) {
            const candidate = plugins[i]
            if (!candidate || candidate === winner
                    || !candidate.transient || !candidate.active)
                continue
            if (typeof candidate.close === "function")
                candidate.close()
        }
    }

    onActivePluginChanged: {
        dismissTransients()

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

    function backgroundTap(screenName) {
        const visible = visiblePluginFor(screenName)
        if (visible && visible.name !== "idle" && visible.handlesBackgroundTap) {
            visible.backgroundTapped()
            return true
        }
        return false
    }

    function hoverEntered(screenName) {
        hoverClearTimer.stop()
        pluginHoverExitTimer.stop()

        if (!activePlugin || activePlugin.name === "idle")
            IslandState.requestScreen(screenName)

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
        onTriggered: IslandState.hovered = false
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
        IslandState.resetHostPublication()
    }
}
