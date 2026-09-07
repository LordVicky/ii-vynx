pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// Window-switcher presentation adapter over ii-vynx HyprlandData. It reuses
// the shell's existing client refresh owner and only dispatches user actions.
Singleton {
    id: root

    // The concrete plugin registers here so always-loaded K4 shortcut routing
    // can commit the active selection on compositor modifier release.
    property var plugin: null

    readonly property var windows: HyprlandData.windowList
        .filter(window => window && window.address && !(window.hidden ?? false))
        .slice()
        .sort((a, b) => (a.focusHistoryID ?? 9999) - (b.focusHistoryID ?? 9999))
    readonly property int count: windows.length

    function refresh() { HyprlandData.updateWindowList() }
    function appName(window) {
        if (!window) return ""
        return String(window.class || window.initialClass || window.title || "Window")
    }
    function title(window) { return String(window?.title || appName(window)) }
    function workspace(window) {
        const id = window?.workspace?.id
        return id && id > 0 ? String(id) : ""
    }
    function activate(window) {
        if (!window?.address) return
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${window.address}" })`)
    }
    function close(window) {
        if (!window?.address) return
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${window.address}" })`)
        Qt.callLater(refresh)
    }
}
