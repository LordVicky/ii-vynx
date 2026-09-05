pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// k4 workspace contract backed by the existing Quickshell Hyprland service.
Singleton {
    id: root

    readonly property int minimumOverviewWorkspaces: 10

    readonly property var list: {
        const values = Hyprland.workspaces.values.slice()
        values.sort((a, b) => a.id - b.id)
        return values
    }

    // Follow the workspace on the compositor-focused monitor. This is the same
    // monitor-aware source ii-vynx Overview uses and avoids opening K4 Windows on
    // a stale workspace when another workspace object still reports focused.
    readonly property int activeId: {
        const focusedMonitorWorkspace = Number(
            Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1)
        if (isFinite(focusedMonitorWorkspace) && focusedMonitorWorkspace > 0)
            return focusedMonitorWorkspace

        for (let i = 0; i < list.length; ++i) {
            if (list[i].focused)
                return list[i].id
        }
        return -1
    }

    // The overview must expose empty workspace destinations too. Keep a
    // continuous 1..N range with ten slots minimum, expanding automatically for
    // users whose live workspace ids extend beyond ten.
    readonly property var overviewList: {
        let highestId = root.minimumOverviewWorkspaces
        if (root.activeId > 0 && root.activeId <= 100)
            highestId = Math.max(highestId, root.activeId)

        for (let i = 0; i < root.list.length; ++i) {
            const id = Number(root.list[i]?.id ?? -1)
            if (isFinite(id) && id > highestId && id <= 100)
                highestId = id
        }

        const values = []
        for (let id = 1; id <= highestId; ++id)
            values.push({ id: id })
        return values
    }
}
