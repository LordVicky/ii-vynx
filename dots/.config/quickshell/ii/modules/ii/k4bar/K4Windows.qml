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
        HyprlandData.updateMonitors()
        HyprlandData.updateWorkspaces()
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

    function isFullscreen(window) {
        return Number(window?.fullscreen ?? 0) > 0
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

    function monitorForWorkspace(workspaceId) {
        const id = Number(workspaceId)
        if (!isFinite(id) || id <= 0)
            return null

        const workspaceData = HyprlandData.workspaceById[id]
        const workspaceMonitorId = Number(
            workspaceData?.monitorID ?? workspaceData?.monitorId ?? -1)
        const workspaceMonitorName = String(workspaceData?.monitor || "")

        for (let i = 0; i < HyprlandData.monitors.length; ++i) {
            const monitor = HyprlandData.monitors[i]
            if (workspaceMonitorId >= 0 && Number(monitor?.id) === workspaceMonitorId)
                return monitor
            if (workspaceMonitorName.length > 0
                    && String(monitor?.name || "") === workspaceMonitorName)
                return monitor
            if (Number(monitor?.activeWorkspace?.id) === id)
                return monitor
        }

        const rows = windowsForWorkspace(id)
        if (rows.length > 0) {
            const monitorId = Number(rows[0]?.monitor ?? -1)
            for (let i = 0; i < HyprlandData.monitors.length; ++i) {
                if (Number(HyprlandData.monitors[i]?.id) === monitorId)
                    return HyprlandData.monitors[i]
            }
        }

        return HyprlandData.monitors.length > 0 ? HyprlandData.monitors[0] : null
    }

    function workspaceGeometry(workspaceId) {
        const monitor = monitorForWorkspace(workspaceId)
        if (!monitor)
            return ({ x: 0, y: 0, width: 1, height: 1, monitor: null })

        const reserved = monitor.reserved ?? [0, 0, 0, 0]
        const left = Math.max(0, Number(reserved[0] ?? 0))
        const top = Math.max(0, Number(reserved[1] ?? 0))
        const right = Math.max(0, Number(reserved[2] ?? 0))
        const bottom = Math.max(0, Number(reserved[3] ?? 0))
        const rotated = Math.abs(Number(monitor.transform ?? 0)) % 2 === 1
        const monitorWidth = Math.max(1, Number(
            rotated ? monitor.height : monitor.width) || 1)
        const monitorHeight = Math.max(1, Number(
            rotated ? monitor.width : monitor.height) || 1)

        return ({
            x: Number(monitor.x ?? 0) + left,
            y: Number(monitor.y ?? 0) + top,
            width: Math.max(1, monitorWidth - left - right),
            height: Math.max(1, monitorHeight - top - bottom),
            monitor: monitor
        })
    }

    function windowGeometry(window) {
        // A fullscreen client owns the visible workspace even when Hyprland's
        // client snapshot retains pre-fullscreen at/size geometry. Normalize it
        // to the whole workspace so the overview matches what is actually on
        // screen while keeping the same native client for focus/drag/close.
        if (root.isFullscreen(window))
            return ({ x: 0, y: 0, width: 1, height: 1 })

        const workspaceRect = workspaceGeometry(workspaceId(window))
        const rawX = Number(window?.at?.[0] ?? workspaceRect.x)
        const rawY = Number(window?.at?.[1] ?? workspaceRect.y)
        const rawWidth = Math.max(1, Number(window?.size?.[0] ?? 1))
        const rawHeight = Math.max(1, Number(window?.size?.[1] ?? 1))

        const x = Math.max(0, Math.min(1,
            (rawX - workspaceRect.x) / workspaceRect.width))
        const y = Math.max(0, Math.min(1,
            (rawY - workspaceRect.y) / workspaceRect.height))
        const width = Math.max(0.01, Math.min(1 - x,
            rawWidth / workspaceRect.width))
        const height = Math.max(0.01, Math.min(1 - y,
            rawHeight / workspaceRect.height))

        return ({ x: x, y: y, width: width, height: height })
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

    function swapWindows(window, targetWindow, direction) {
        if (!window?.address || !targetWindow?.address
                || window.address === targetWindow.address)
            return
        const dir = direction === "l" ? "l" : "r"
        Hyprland.dispatch(`hl.dsp.layout("swapaddrdir ${targetWindow.address} ${dir} ${window.address} true")`)
        Qt.callLater(refresh)
    }

    function focusWorkspace(workspaceId) {
        const id = Number(workspaceId)
        if (!isFinite(id) || id <= 0)
            return
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`)
    }
}
