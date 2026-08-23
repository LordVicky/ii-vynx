import QtQuick
import Quickshell.Io
import qs.services

// Pinned k4 PanelPlugin ownership/navigation contract adapted to ii-vynx.
// Presentation services are attached in later K4-06 slices; this object owns
// only panel state and island arbitration.
K4Plugin {
    id: root

    name: "panel"
    title: "Control Center"
    priority: 60
    active: enabled && open

    // "controls" | "notifications" | "wifi" | "bluetooth" | "sonido"
    property string tab: "controls"
    property bool open: false

    islandWidth: 860
    islandHeight: tab === "controls" ? 268 : 400
    grabKeyboard: open
    handlesBackgroundTap: true
    closeOnHoverExit: true

    onBackgroundTapped: toggle()
    onHoverTimedOut: close()

    function toggle(wanted) {
        const wantsTab = wanted !== undefined && String(wanted).length > 0
        open = !open || (wantsTab && wanted !== tab)

        if (!open)
            return

        if (wantsTab)
            tab = wanted
        K4Notifications.dismissToast()
        if (tab === "notifications")
            K4Notifications.markRead()
    }

    function openTab(wanted) {
        tab = wanted
        open = true
        K4Notifications.dismissToast()
        if (tab === "notifications")
            K4Notifications.markRead()
    }

    function close() {
        open = false
    }

    Connections {
        target: Notifications
        function onNotify(notification) { root.open = false }
    }

    Component.onCompleted: K4Panel.plugin = root
    Component.onDestruction: {
        if (K4Panel.plugin === root)
            K4Panel.plugin = null
    }

    IpcHandler {
        target: "k4.panel"
        function toggle(): void { root.toggle("controls") }
        function notifications(): void { root.toggle("notifications") }
        function wifi(): void { root.openTab("wifi") }
        function bluetooth(): void { root.openTab("bluetooth") }
        function sonido(): void { root.openTab("sonido") }
        function close(): void { root.close() }
    }

    view: Component {
        K4PanelView { plugin: root }
    }
}
