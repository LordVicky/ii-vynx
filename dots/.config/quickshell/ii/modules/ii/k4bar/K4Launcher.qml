pragma Singleton

import Quickshell

// Stable entry point for shell-owned shortcuts/IPC without exposing launcher
// plugin internals. The live K4LauncherPlugin registers itself here.
Singleton {
    id: root

    property var plugin: null
    property bool pendingOpen: false
    property string pendingQuery: ""

    readonly property bool available: plugin !== null && (plugin.enabled ?? false)
    readonly property bool open: plugin?.open ?? false

    onPluginChanged: {
        if (!plugin || !pendingOpen)
            return
        const query = pendingQuery
        pendingOpen = false
        pendingQuery = ""
        plugin.openSearch(query)
    }

    function toggle() {
        if (plugin) {
            plugin.toggle()
            return
        }
        pendingOpen = !pendingOpen
        if (!pendingOpen)
            pendingQuery = ""
    }

    function openSearch(query = "") {
        if (plugin) {
            plugin.openSearch(query)
            return
        }
        pendingOpen = true
        pendingQuery = String(query || "")
    }

    function close() {
        pendingOpen = false
        pendingQuery = ""
        plugin?.close()
    }
}
