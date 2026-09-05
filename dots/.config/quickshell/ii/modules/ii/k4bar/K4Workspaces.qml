pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// k4 workspace contract backed by the existing Quickshell Hyprland service.
Singleton {
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
}
