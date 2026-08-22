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

    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? -1
}
