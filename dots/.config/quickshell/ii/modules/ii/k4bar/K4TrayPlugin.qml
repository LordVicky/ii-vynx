import QtQuick
import Quickshell.Io

// Tray plugin adapted from k4ditano/k4 TrayPlugin at the pinned source commit.
// Item/menu ownership remains in ii-vynx TrayService and Quickshell SystemTray.
K4Plugin {
    id: root

    name: "tray"
    title: "System Tray"
    priority: 63
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property var selected: null

    islandWidth: 640
    islandHeight: 360

    handlesBackgroundTap: true
    onBackgroundTapped: {}
    closeOnHoverExit: true
    hoverExitDelay: 900
    onHoverTimedOut: close()

    function toggle() {
        if (open) {
            close()
            return
        }
        K4Panel.close()
        K4Notifications.dismissToast()
        if (!selected || K4Tray.sorted.indexOf(selected) < 0)
            selected = K4Tray.count > 0 ? K4Tray.sorted[0] : null
        open = true
    }

    function close() { open = false }
    function select(item) { selected = item }

    Connections {
        target: K4Tray
        function onSortedChanged() {
            if (root.selected && K4Tray.sorted.indexOf(root.selected) < 0)
                root.selected = K4Tray.count > 0 ? K4Tray.sorted[0] : null
        }
    }

    IpcHandler {
        target: "k4.tray"
        function toggle(): void { root.toggle() }
        function close(): void { root.close() }
    }

    view: Component { K4TrayView { plugin: root } }
}
