import QtQuick
import Quickshell.Io

// Shortcut viewer adapted from k4ditano/k4 KeysPlugin at the pinned source
// commit. Data ownership remains in ii-vynx HyprlandKeybinds via K4Keys.
K4Plugin {
    id: root

    name: "keys"
    title: "Shortcuts"
    priority: 65
    application: true
    applicationGlyph: String.fromCodePoint(0xF030C)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property string query: ""
    readonly property var entries: K4Keys.filter(query)
    readonly property int count: entries.length

    islandWidth: 760
    islandHeight: 440

    function openKeys() {
        K4Panel.close()
        K4Notifications.dismissToast()
        query = ""
        open = true
    }

    function openApplication() {
        if (!enabled) return false
        openKeys()
        return true
    }

    function toggle() { open ? close() : openKeys() }

    function close() {
        if (!open) return
        open = false
        query = ""
    }

    function keys(combo) { return K4Keys.keys(combo) }

    IpcHandler {
        target: "k4.keys"
        function toggle(): void { root.toggle() }
        function open(): void { root.openKeys() }
        function close(): void { root.close() }
    }

    view: Component { K4KeysView { plugin: root } }
}
