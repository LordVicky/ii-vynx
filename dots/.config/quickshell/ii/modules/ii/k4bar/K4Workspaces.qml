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

    // Match pinned k4's focus seam: the workspace objects carry their own focus
    // state, so activeId changes in the same update path that drives pill focus.
    readonly property int activeId: {
        for (let i = 0; i < list.length; ++i) {
            if (list[i].focused)
                return list[i].id
        }
        return -1
    }
}
