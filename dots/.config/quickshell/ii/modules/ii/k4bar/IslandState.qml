pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.modules.common

// Island host state adapted from k4ditano/k4 services/Island.qml at the
// pinned source commit. Copyright (c) 2026 k4ditano — MIT,
// see licenses/k4-NOTICE.txt.
Singleton {
    id: root

    // Published by the host. Plugins read these; they do not choose the winner.
    property bool hovered: false
    property string occupant: ""
    property bool open: false

    // The collapsed pill exists on every screen. An expanded global action
    // belongs to exactly one screen.
    property string activeScreen: ""
    property string requestedScreen: ""

    function requestScreen(name) {
        if (name)
            requestedScreen = String(name)
    }

    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor
        if (monitor?.name)
            return monitor.name
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    function requestFocusedScreen() {
        requestScreen(focusedScreen())
    }

    function takeRequestedScreen() {
        const chosen = requestedScreen || focusedScreen()
        requestedScreen = ""
        return chosen
    }

    function useScreen(name) {
        activeScreen = name || focusedScreen()
        requestedScreen = ""
    }

    // Preserve k4's public vocabulary even though ii stores English config.
    readonly property string position:
        Config.options.bar.k4.position === "bottom" ? "abajo" : "arriba"

    // Geometry is in screen-local coordinates and includes the inverse wings.
    // Keep upstream field names so adapted k4 plugins can consume it directly.
    property var rect: ({ x: 0, y: 0, ancho: 0, alto: 0 })
    property var rects: ({})

    function publishRect(screenName, value, isPrimary) {
        if (!screenName)
            return
        const next = Object.assign({}, rects)
        next[screenName] = value
        rects = next
        if (isPrimary)
            rect = value
    }

    // Permanent placement belongs to Config. Plugins can temporarily borrow it.
    property string placementOwner: ""
    property real requestedPlacement: -1

    readonly property real basePlacement:
        Math.max(0, Math.min(100, Config.options.bar.k4.alignment)) / 100
    readonly property real placement:
        requestedPlacement >= 0 ? requestedPlacement : basePlacement

    function requestPlacement(owner, fraction, durationMs) {
        if (!owner)
            return
        placementOwner = String(owner)
        requestedPlacement = Math.max(0, Math.min(1, Number(fraction) || 0))
        if (durationMs > 0)
            placementReleaseTimer.arm(durationMs)
        else
            placementReleaseTimer.stop()
    }

    function releasePlacement(owner) {
        if (placementOwner === "" || (owner && owner !== placementOwner))
            return
        placementOwner = ""
        requestedPlacement = -1
        placementReleaseTimer.stop()
    }

    Timer {
        id: placementReleaseTimer
        onTriggered: root.releasePlacement(root.placementOwner)

        function arm(ms) {
            stop()
            interval = ms
            start()
        }
    }

    // Physical island gesture requests. The host owns the animations. Gesture
    // names intentionally remain k4's sacudida/empujon/tiron contract.
    signal gesture(string name, real strength)
    property real lastGestureAt: 0

    function requestGesture(owner, name, strength) {
        if (!owner || !name)
            return
        const now = Date.now()
        if (now - lastGestureAt < 500)
            return
        lastGestureAt = now
        const normalizedStrength = strength === undefined
            ? 1
            : Math.max(0.2, Math.min(1, Number(strength) || 0))
        gesture(String(name), normalizedStrength)
    }

    // Keep the layer surface mapped while temporarily removing rendering/input.
    property bool hidden: false
    property int systemDialogs: 0

    function openSystemDialog() {
        systemDialogs += 1
    }

    function closeSystemDialog() {
        systemDialogs = Math.max(0, systemDialogs - 1)
    }

    readonly property bool suppressed: hidden || systemDialogs > 0

    // Upstream safety net: a destroyed dialog owner must not leave the island
    // permanently suppressed. This process exists only while a dialog is open.
    Process {
        id: dialogProbe
        command: ["pgrep", "-c", "-x", "zenity"]
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(String(text).trim(), 10)
                if (isFinite(count) && count <= 0)
                    root.systemDialogs = 0
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.systemDialogs > 0
        onTriggered: dialogProbe.running = true
    }

    // ii can unload the entire k4 host when switching bar variants. Reset
    // host-scoped state so a debug hide/dialog/placement cannot poison a later
    // k4 activation through this long-lived singleton.
    function resetHostPublication() {
        hovered = false
        occupant = ""
        open = false
        activeScreen = ""
        requestedScreen = ""
        rect = ({ x: 0, y: 0, ancho: 0, alto: 0 })
        rects = ({})
        hidden = false
        systemDialogs = 0
        releasePlacement("")
    }
}
