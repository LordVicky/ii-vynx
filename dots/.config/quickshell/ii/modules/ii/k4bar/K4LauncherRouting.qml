import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

// Variant-local compatibility layer for ii-vynx's existing shell shortcuts and
// IPC names. This Scope only exists while the K4 bar owns the bar variant, so
// the same user bindings dispatch to K4 without competing Standard surfaces.
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

    function toggleWindowsOverview() {
        if (K4Windows.plugin)
            K4Windows.plugin.toggleOverview()
    }

    function triggerWindowSwitcher(direction) {
        if (K4Windows.plugin)
            K4Windows.plugin.triggerSwitcher(direction)
    }

    IpcHandler {
        target: "search"

        function toggle(): void { K4Launcher.toggle() }
        function workspacesToggle(): void { root.toggleWindowsOverview() }
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

    // Reuse ii-vynx's existing Super+Tab action name. Overview.qml is not
    // instantiated in K4 mode, so this K4-local handler owns the shortcut.
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles K4 workspace and windows overview"
        onPressed: root.toggleWindowsOverview()
    }

    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes active K4 keyboard surfaces"
        onPressed: root.closeKeyboardSurfaces()
    }

    GlobalShortcut {
        name: "windowsSwitcherToggle"
        description: "Cycles K4 windows forward"
        onPressed: root.triggerWindowSwitcher(1)
    }

    GlobalShortcut {
        name: "windowsSwitcherPrevious"
        description: "Cycles K4 windows backward"
        onPressed: root.triggerWindowSwitcher(-1)
    }

    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles the active K4 launcher on release"

        onPressed: GlobalStates.superReleaseMightTrigger = true
        onReleased: {
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
