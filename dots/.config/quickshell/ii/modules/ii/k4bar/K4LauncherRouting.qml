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

    IpcHandler {
        target: "search"

        function toggle(): void { K4Launcher.toggle() }
        function workspacesToggle(): void {}
        function close(): void {
            K4Launcher.close()
            K4Clipboard.closeSurface()
        }
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
        name: "overviewWorkspacesClose"
        description: "Closes active K4 keyboard surfaces"
        onPressed: {
            K4Launcher.close()
            K4Clipboard.closeSurface()
        }
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
