import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

// Variant-local compatibility layer for ii-vynx's existing search shortcuts
// and IPC names. This Scope only exists while the K4 bar owns the bar variant,
// so the same user bindings dispatch to K4 without a competing ii Overview.
Scope {
    id: root

    Component.onCompleted: GlobalStates.overviewOpen = false
    Component.onDestruction: {
        K4Launcher.close()
        K4Clipboard.closeSurface()
        if (K4Windows.plugin)
            K4Windows.plugin.close()
    }

    // Keep stale/external Overview state from reopening when the user later
    // switches back to Standard. The Standard Overview surface is unloaded
    // while this router exists.
    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen)
                GlobalStates.overviewOpen = false
        }
    }

    function closeKeyboardSurfaces() {
        K4Launcher.close()
        K4Clipboard.closeSurface()
        if (K4Windows.plugin)
            K4Windows.plugin.close()
    }

    function toggleWindows(direction = 1) {
        if (K4Windows.plugin)
            K4Windows.plugin.toggle(direction)
    }

    function commitWindows() {
        if (K4Windows.plugin?.open)
            K4Windows.plugin.choose()
    }

    IpcHandler {
        target: "search"

        function toggle(): void { K4Launcher.toggle() }
        function workspacesToggle(): void { root.toggleWindows(1) }
        function close(): void { root.closeKeyboardSurfaces() }
        function open(): void { K4Launcher.openSearch("") }
        function toggleReleaseInterrupt(): void {
            GlobalStates.superReleaseMightTrigger = false
        }
        function clipboardToggle(): void { K4Clipboard.toggleSurface() }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles the active K4 launcher on press"
        onPressed: K4Launcher.toggle()
    }

    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Cycles K4 windows with Super+Tab"
        onPressed: root.toggleWindows(1)
    }

    GlobalShortcut {
        name: "windowsSwitcherToggle"
        description: "Cycles K4 windows forward with Alt+Tab"
        onPressed: root.toggleWindows(1)
    }

    GlobalShortcut {
        name: "windowsSwitcherPrevious"
        description: "Cycles K4 windows backward with Alt+Shift+Tab"
        onPressed: root.toggleWindows(-1)
    }

    GlobalShortcut {
        name: "windowsSwitcherCommit"
        description: "Commits the active K4 window selection on Alt release"
        onPressed: root.commitWindows()
    }

    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes active K4 keyboard surfaces"
        onPressed: root.closeKeyboardSurfaces()
    }

    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Commits K4 Super+Tab or toggles the launcher on Super release"

        onPressed: GlobalStates.superReleaseMightTrigger = true
        onReleased: {
            // Super+Tab owns this release while the K4 window switcher is open.
            // Commit before consulting the launcher interruption latch because
            // Tab intentionally interrupts the normal Super-release launcher.
            if (K4Windows.plugin?.open) {
                K4Windows.plugin.choose()
                GlobalStates.superReleaseMightTrigger = true
                return
            }
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true
                return
            }
            K4Launcher.toggle()
        }
    }

    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of K4 launcher being toggled on release"
        onPressed: GlobalStates.superReleaseMightTrigger = false
    }

    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggles the K4 clipboard utility"
        onPressed: K4Clipboard.toggleSurface()
    }
}
