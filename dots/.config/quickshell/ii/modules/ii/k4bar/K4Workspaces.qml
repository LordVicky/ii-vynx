pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Minimal K4 workspace seam used only by the Alt-Tab current-workspace filter.
Singleton {
    id: root

    readonly property var list: {
        const values = Hyprland.workspaces.values.slice()
        values.sort((a, b) => a.id - b.id)
        return values
    }

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
