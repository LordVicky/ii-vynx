pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// K4 window presentation adapter over ii-vynx's existing Wayland/Hyprland
// owners. HyprlandData remains the client-state owner, ToplevelManager supplies
// native Wayland toplevels for previews, and compositor actions stay in-process
// through Quickshell's Hyprland dispatcher.
Singleton {
    id: root

    // The concrete plugin registers here so always-loaded shell shortcuts can
    // route to K4 only while the K4 bar is actually instantiated.
    property var plugin: null

    readonly property var windows: HyprlandData.windowList
        .filter(window => window && window.address && !(window.hidden ?? false))
        .slice()
        .sort((a, b) => (a.focusHistoryID ?? 9999) - (b.focusHistoryID ?? 9999))
    readonly property int count: windows.length

    function refresh() {
        HyprlandData.updateWindowList()
    }

    function appName(window) {
        if (!window)
            return ""
        return String(window.class || window.initialClass || window.title || "Window")
    }

    function title(window) {
        return String(window?.title || appName(window))
    }

    function appIcon(window) {
        return Quickshell.iconPath(AppSearch.guessIcon(appName(window)), "image-missing")
    }

    function workspaceId(window) {
        const id = Number(window?.workspace?.id ?? -1)
        return isFinite(id) && id > 0 ? id : -1
    }

    function workspace(window) {
        const id = workspaceId(window)
        return id > 0 ? String(id) : ""
    }

    function windowsForWorkspace(workspaceId) {
        const id = Number(workspaceId)
        return windows.filter(window => root.workspaceId(window) === id)
    }

    function windowsOutsideWorkspace(workspaceId) {
        const id = Number(workspaceId)
        return windows.filter(window => {
            const windowWorkspace = root.workspaceId(window)
            return windowWorkspace > 0 && windowWorkspace !== id
        })
    }

    function windowCountForWorkspace(workspaceId) {
        return windowsForWorkspace(workspaceId).length
    }

    function switcherWindows(currentWorkspaceOnly) {
        if (!currentWorkspaceOnly)
            return windows
        return windowsForWorkspace(K4Workspaces.activeId)
    }

    function normalizedAddress(value) {
        let address = String(value || "").toLowerCase()
        if (address.length === 0)
            return ""
        if (!address.startsWith("0x"))
            address = "0x" + address
        return address
    }

    function toplevelFor(window) {
        const wanted = normalizedAddress(window?.address)
        if (wanted.length === 0)
            return null

        const values = ToplevelManager.toplevels?.values ?? []
        for (let i = 0; i < values.length; ++i) {
            const toplevel = values[i]
            const address = normalizedAddress(toplevel?.HyprlandToplevel?.address)
            if (address === wanted)
                return toplevel
        }
        return null
    }

    function activate(window) {
        if (!window?.address)
            return
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${window.address}" })`)
    }

    function close(window) {
        if (!window?.address)
            return
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${window.address}" })`)
        Qt.callLater(refresh)
    }

    function moveToWorkspace(window, workspaceId) {
        const id = Number(workspaceId)
        if (!window?.address || !isFinite(id) || id <= 0)
            return
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${id}, follow = false, window = "address:${window.address}" })`)
        Qt.callLater(refresh)
    }

    function focusWorkspace(workspaceId) {
        const id = Number(workspaceId)
        if (!isFinite(id) || id <= 0)
            return
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`)
    }
}
