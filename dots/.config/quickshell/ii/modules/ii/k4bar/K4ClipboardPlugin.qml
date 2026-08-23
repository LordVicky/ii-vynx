import QtQuick
import Quickshell.Io

// Clipboard utility adapted from k4ditano/k4 ClipboardPlugin at the pinned
// source commit. Clipboard ownership stays in ii-vynx Cliphist via K4Clipboard.
K4Plugin {
    id: root

    name: "clipboard"
    title: "Clipboard"
    priority: 82
    application: true
    applicationGlyph: String.fromCodePoint(0xF014D)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property string query: ""
    property int index: 0
    readonly property var entries: K4Clipboard.filter(query)
    readonly property int count: entries.length

    islandWidth: 720
    islandHeight: 470

    function openClipboard() {
        K4Clipboard.refresh()
        K4Panel.close()
        K4Notifications.dismissToast()
        query = ""
        index = 0
        open = true
    }

    function openApplication() {
        if (!enabled) return false
        openClipboard()
        return true
    }

    function toggle() { open ? close() : openClipboard() }

    function close() {
        if (!open) return
        open = false
        query = ""
        index = 0
    }

    function moveSelection(delta) {
        if (count === 0) return
        index = Math.max(0, Math.min(count - 1, index + delta))
    }

    function choose() {
        const row = entries[index]
        if (!row) return
        K4Clipboard.copy(row)
        close()
    }

    function removeCurrent() {
        const row = entries[index]
        if (!row) return
        K4Clipboard.remove(row)
        index = Math.max(0, Math.min(index, count - 2))
    }

    function pinCurrent() {
        const row = entries[index]
        if (row) K4Clipboard.togglePin(row)
    }

    onCountChanged: {
        if (index >= count) index = Math.max(0, count - 1)
    }

    Component.onCompleted: K4Clipboard.plugin = root
    Component.onDestruction: {
        if (K4Clipboard.plugin === root)
            K4Clipboard.plugin = null
    }

    IpcHandler {
        target: "k4.clipboard"
        function toggle(): void { root.toggle() }
        function open(): void { root.openClipboard() }
        function close(): void { root.close() }
        function clear(): void { K4Clipboard.clear() }
    }

    view: Component { K4ClipboardView { plugin: root } }
}
