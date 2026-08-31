import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Lean K4 monitor arrangement utility. HyprlandData remains the monitor-state
// owner; this plugin only keeps an in-memory edit draft and applies it live.
K4Plugin {
    id: root

    name: "displays"
    title: "Displays"
    priority: 67
    application: true
    applicationGlyph: String.fromCodePoint(0xF037A)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property var drafts: []
    property int selectedIndex: 0
    property bool dirty: false
    property bool busy: false
    property bool awaitingRefresh: false
    property bool refreshAfterApply: false
    property string message: ""
    property bool messageError: false
    property string applyStdout: ""
    property string applyStderr: ""

    readonly property var selectedDraft: selectedIndex >= 0 && selectedIndex < drafts.length
        ? drafts[selectedIndex] : null

    islandWidth: 820
    islandHeight: 500

    function luaString(value) {
        return JSON.stringify(String(value))
    }

    function currentMode(monitor) {
        const modes = Array.isArray(monitor?.availableModes)
            ? monitor.availableModes : []
        const exact = String(monitor?.width ?? 0) + "x" + String(monitor?.height ?? 0)
            + "@" + Number(monitor?.refreshRate ?? 0).toFixed(2) + "Hz"
        if (modes.indexOf(exact) >= 0)
            return exact
        const prefix = String(monitor?.width ?? 0) + "x" + String(monitor?.height ?? 0) + "@"
        for (let i = 0; i < modes.length; ++i)
            if (String(modes[i]).indexOf(prefix) === 0)
                return String(modes[i])
        return exact
    }

    function cloneMonitor(monitor) {
        return {
            name: String(monitor?.name ?? ""),
            description: String(monitor?.description ?? monitor?.name ?? ""),
            mode: currentMode(monitor),
            availableModes: Array.isArray(monitor?.availableModes)
                ? monitor.availableModes.slice() : [],
            x: Math.round(Number(monitor?.x ?? 0)),
            y: Math.round(Number(monitor?.y ?? 0)),
            scale: Number(monitor?.scale ?? 1),
            transform: Math.round(Number(monitor?.transform ?? 0))
        }
    }

    function rebuildDrafts() {
        const source = HyprlandData.monitors || []
        const next = []
        for (let i = 0; i < source.length; ++i) {
            if (source[i]?.disabled === true)
                continue
            const copy = cloneMonitor(source[i])
            if (copy.name.length > 0)
                next.push(copy)
        }
        drafts = next
        selectedIndex = next.length === 0 ? 0
            : Math.max(0, Math.min(selectedIndex, next.length - 1))
        dirty = false
        if (next.length === 0 && !messageError)
            message = "No active displays"
    }

    function updateSelected(key, value) {
        if (!selectedDraft || busy)
            return
        const next = drafts.slice()
        const changed = Object.assign({}, next[selectedIndex])
        changed[key] = value
        next[selectedIndex] = changed
        drafts = next
        dirty = true
        message = "Unsaved session changes"
        messageError = false
    }

    function modeSize(draft) {
        const match = String(draft?.mode ?? "").match(/^(\d+)x(\d+)/)
        return match ? { width: Number(match[1]), height: Number(match[2]) }
            : { width: 1920, height: 1080 }
    }

    function logicalSize(draft) {
        const size = modeSize(draft)
        const rotated = draft?.transform === 1 || draft?.transform === 3
        const scale = Math.max(0.5, Number(draft?.scale ?? 1))
        return {
            width: Math.round((rotated ? size.height : size.width) / scale),
            height: Math.round((rotated ? size.width : size.height) / scale)
        }
    }

    function normalizePositions(source) {
        if (source.length === 0)
            return source
        let minX = source[0].x
        let minY = source[0].y
        for (let i = 1; i < source.length; ++i) {
            minX = Math.min(minX, source[i].x)
            minY = Math.min(minY, source[i].y)
        }
        if (minX === 0 && minY === 0)
            return source
        const next = source.slice()
        for (let i = 0; i < next.length; ++i) {
            const copy = Object.assign({}, next[i])
            copy.x = Math.round(copy.x - minX)
            copy.y = Math.round(copy.y - minY)
            next[i] = copy
        }
        return next
    }

    function placeSelected(where) {
        if (!selectedDraft || drafts.length < 2 || busy)
            return
        let referenceIndex = selectedIndex === 0 ? 1 : 0
        const mine = logicalSize(selectedDraft)
        const reference = drafts[referenceIndex]
        const theirs = logicalSize(reference)
        const next = drafts.slice()
        const changed = Object.assign({}, selectedDraft)

        if (where === "left") {
            changed.x = reference.x - mine.width
            changed.y = reference.y
        } else if (where === "right") {
            changed.x = reference.x + theirs.width
            changed.y = reference.y
        } else if (where === "above") {
            changed.x = reference.x
            changed.y = reference.y - mine.height
        } else if (where === "below") {
            changed.x = reference.x
            changed.y = reference.y + theirs.height
        } else if (where === "mirror") {
            changed.x = reference.x
            changed.y = reference.y
        } else {
            return
        }

        next[selectedIndex] = changed
        drafts = normalizePositions(next)
        dirty = true
        message = "Unsaved session changes"
        messageError = false
    }

    function monitorStatement(draft) {
        return "hl.monitor({ output = " + luaString(draft.name)
            + ", mode = " + luaString(draft.mode)
            + ", position = " + luaString(Math.round(draft.x) + "x" + Math.round(draft.y))
            + ", scale = " + Number(draft.scale).toFixed(2)
            + ", transform = " + Math.round(draft.transform) + " })"
    }

    function refresh(afterApply) {
        refreshAfterApply = afterApply === true
        awaitingRefresh = true
        messageError = false
        if (!refreshAfterApply)
            message = "Refreshing displays…"
        HyprlandData.updateMonitors()
        refreshFallback.restart()
    }

    function finishRefresh() {
        if (!awaitingRefresh)
            return
        awaitingRefresh = false
        refreshFallback.stop()
        rebuildDrafts()
        if (refreshAfterApply)
            message = "Applied for this session"
        else if (drafts.length > 0)
            message = String(drafts.length) + (drafts.length === 1 ? " display" : " displays")
        refreshAfterApply = false
    }

    function apply() {
        if (busy || drafts.length === 0)
            return
        if (!dirty) {
            message = "No changes to apply"
            messageError = false
            return
        }

        const statements = []
        for (let i = 0; i < drafts.length; ++i)
            statements.push(monitorStatement(drafts[i]))

        applyStdout = ""
        applyStderr = ""
        message = "Applying display layout…"
        messageError = false
        busy = true
        applyProcess.command = ["hyprctl", "eval", statements.join("\n")]
        applyProcess.running = true
    }

    function openDisplays() {
        K4Panel.close()
        K4Notifications.dismissToast()
        selectedIndex = 0
        rebuildDrafts()
        open = true
        refresh(false)
    }

    function openApplication() {
        if (!enabled)
            return false
        openDisplays()
        return true
    }

    function close() {
        if (!open)
            return
        open = false
        awaitingRefresh = false
        refreshFallback.stop()
        message = ""
        messageError = false
    }

    function toggle() {
        open ? close() : openDisplays()
    }

    Connections {
        target: HyprlandData
        function onMonitorsChanged() {
            root.finishRefresh()
        }
    }

    Timer {
        id: refreshFallback
        interval: 1400
        onTriggered: root.finishRefresh()
    }

    Process {
        id: applyProcess

        stdout: StdioCollector {
            onStreamFinished: root.applyStdout = text
        }
        stderr: StdioCollector {
            onStreamFinished: root.applyStderr = text
        }

        onExited: function(exitCode, exitStatus) {
            root.busy = false
            const combined = (root.applyStdout + "\n" + root.applyStderr).trim()
            if (exitCode !== 0 || combined.toLowerCase().indexOf("error:") >= 0) {
                root.message = combined.length > 0 ? combined : "Hyprland rejected the display layout"
                root.messageError = true
                return
            }
            root.refresh(true)
        }
    }

    IpcHandler {
        target: "k4.displays"
        function toggle(): void { root.toggle() }
        function open(): void { root.openDisplays() }
        function close(): void { root.close() }
        function refresh(): void { root.refresh(false) }
        function apply(): void { root.apply() }
        function place(where: string): void { root.placeSelected(where) }
    }

    view: Component { K4DisplaysView { plugin: root } }
}
