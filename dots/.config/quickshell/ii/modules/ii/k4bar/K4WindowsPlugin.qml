import QtQuick
import Quickshell.Io

// Window switcher adapted from k4ditano/k4 WindowsPlugin at the pinned source
// commit. Client ownership remains in ii-vynx HyprlandData.
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
    readonly property var entries: K4Windows.windows
    readonly property int count: entries.length

    islandWidth: Math.min(880, Math.max(360, 60 + count * 128))
    islandHeight: 190

    function openWindows(direction = 1) {
        if (!enabled)
            return
        K4Windows.refresh()
        K4Panel.close()
        K4Notifications.dismissToast()
        if (K4Windows.count > 1)
            index = direction < 0 ? K4Windows.count - 1 : 1
        else
            index = 0
        open = K4Windows.count > 0
    }

    function openApplication() {
        if (!enabled) return false
        openWindows(1)
        return open
    }

    function close() { open = false }
    function toggle(direction = 1) {
        if (!open) {
            openWindows(direction)
            return
        }
        if (direction < 0)
            retreat()
        else
            advance()
    }
    function advance() {
        if (count > 0) index = (index + 1) % count
    }
    function retreat() {
        if (count > 0) index = (index - 1 + count) % count
    }
    function choose() {
        const row = entries[index]
        if (!row) return
        close()
        K4Windows.activate(row)
    }
    function closeCurrent() {
        const row = entries[index]
        if (!row) return
        K4Windows.close(row)
        index = Math.max(0, Math.min(index, count - 2))
    }

    onCountChanged: {
        if (count === 0) close()
        else if (index >= count) index = Math.max(0, count - 1)
    }

    Component.onCompleted: K4Windows.plugin = root
    Component.onDestruction: {
        if (K4Windows.plugin === root)
            K4Windows.plugin = null
    }

    IpcHandler {
        target: "k4.windows"
        function toggle(): void { root.toggle(1) }
        function open(): void { root.openWindows(1) }
        function close(): void { root.close() }
        function next(): void { root.advance() }
        function previous(): void { root.retreat() }
        function focus(index: int): void {
            K4Windows.refresh()
            root.index = Math.max(0, Math.min(K4Windows.count - 1, index))
            root.choose()
        }
    }

    view: Component { K4WindowsView { plugin: root } }
}
