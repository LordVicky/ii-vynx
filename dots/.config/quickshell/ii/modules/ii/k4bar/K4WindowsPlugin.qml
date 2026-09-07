import QtQuick
import Quickshell.Io

// K4 owns only the Alt-Tab presentation. Super-Tab workspace management is the
// stock ii-vynx Overview and deliberately does not route through this plugin.
K4Plugin {
    id: root

    name: "windows"
    title: "Windows"
    priority: 83
    application: true
    applicationGlyph: String.fromCodePoint(0xF05B2)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property int index: 0
    property bool altTabCurrentWorkspaceOnly: false
    property bool releaseCommitArmed: false

    readonly property var entries:
        K4Windows.switcherWindows(altTabCurrentWorkspaceOnly)
    readonly property int count: entries.length

    islandWidth: Math.min(1120,
        Math.max(520, 80 + Math.min(count, 4) * 260))
    islandHeight: 320

    function prepare() {
        K4Windows.refresh()
        K4Panel.close()
        K4Notifications.dismissToast()
    }

    function openSwitcher(direction = 1) {
        if (!enabled)
            return
        prepare()
        const rows = K4Windows.switcherWindows(altTabCurrentWorkspaceOnly)
        if (rows.length === 0) {
            close()
            return
        }
        if (rows.length === 1)
            index = 0
        else
            index = direction < 0 ? rows.length - 1 : 1
        open = true
    }

    function triggerSwitcher(direction = 1) {
        if (!open) {
            openSwitcher(direction)
        } else if (direction < 0) {
            retreat()
        } else {
            advance()
        }
        if (open)
            armReleaseCommit()
    }

    function armReleaseCommit() {
        releaseCommitArmed = open && count > 0
    }

    function commitRelease() {
        if (!open || !releaseCommitArmed)
            return false
        releaseCommitArmed = false
        const row = entries[index]
        if (!row) {
            close()
            return false
        }
        chooseWindow(row)
        return true
    }

    function setAltTabCurrentWorkspaceOnly(value) {
        altTabCurrentWorkspaceOnly = Boolean(value)
        index = Math.max(0, Math.min(index, count - 1))
    }

    function openApplication() {
        if (!enabled)
            return false
        prepare()
        if (entries.length === 0) {
            close()
            return false
        }
        index = 0
        releaseCommitArmed = false
        open = true
        return true
    }

    function close() {
        releaseCommitArmed = false
        open = false
    }

    function toggle() {
        if (open)
            close()
        else
            openApplication()
    }

    function advance() {
        if (count > 0)
            index = (index + 1) % count
    }

    function retreat() {
        if (count > 0)
            index = (index - 1 + count) % count
    }

    function chooseWindow(row) {
        if (!row)
            return
        close()
        K4Windows.activate(row)
    }

    function choose() {
        chooseWindow(entries[index])
    }

    function closeCurrent() {
        const row = entries[index]
        if (!row)
            return
        K4Windows.close(row)
        index = Math.max(0, Math.min(index, count - 2))
    }

    onCountChanged: {
        if (open && count === 0)
            close()
        else if (index >= count)
            index = Math.max(0, count - 1)
    }

    Component.onCompleted: K4Windows.plugin = root
    Component.onDestruction: {
        if (K4Windows.plugin === root)
            K4Windows.plugin = null
    }

    IpcHandler {
        target: "k4.windows"
        function toggle(): void { root.toggle() }
        function open(): void { root.openApplication() }
        function switcher(): void { root.openSwitcher(1) }
        function close(): void { root.close() }
        function next(): void { root.advance() }
        function previous(): void { root.retreat() }
        function focus(index: int): void {
            root.index = Math.max(0, Math.min(root.count - 1, index))
            root.choose()
        }
    }

    view: Component { K4WindowsView { plugin: root } }
}
