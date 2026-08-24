import QtQuick
import Quickshell.Io

// In-island settings ownership adapted from k4ditano/k4 SettingsPlugin.qml at
// the pinned source commit. Copyright (c) 2026 k4ditano — MIT, see
// licenses/k4-NOTICE.txt.
K4Plugin {
    id: root

    name: "settings"
    title: "Settings"
    priority: 66
    configurable: false
    application: true
    applicationGlyph: String.fromCodePoint(0xF0493)
    active: enabled && open
    grabKeyboard: open

    property bool open: false
    property var controller: null

    islandWidth: 600
    islandHeight: 640
    handlesBackgroundTap: true
    onBackgroundTapped: {}
    closeOnHoverExit: true
    hoverExitDelay: 1200
    onHoverTimedOut: close()

    function openSettings() {
        if (!enabled)
            return false
        K4Panel.close()
        K4Notifications.dismissToast()
        open = true
        return true
    }

    function openApplication() {
        return openSettings()
    }

    function toggle() {
        if (open)
            close()
        else
            openSettings()
    }

    function close() {
        open = false
    }

    IpcHandler {
        target: "k4.settings"
        function toggle(): void { root.toggle() }
        function close(): void { root.close() }
    }

    view: Component {
        K4SettingsView { plugin: root }
    }
}
