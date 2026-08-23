import QtQuick
import Quickshell.Io

// System monitor adapted from pinned k4 SystemPlugin. Sampling is delegated to
// ii-vynx ResourceUsage/NetworkUsage and is active only while this view is open.
K4Plugin {
    id: root

    name: "system"
    title: "System"
    priority: 62
    application: true
    applicationGlyph: String.fromCodePoint(0xF04BC)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    islandWidth: 700
    islandHeight: 430

    onOpenChanged: {
        if (open) K4System.start()
        else K4System.stop()
    }

    function openSystem() {
        K4Panel.close()
        K4Notifications.dismissToast()
        open = true
    }
    function openApplication() {
        if (!enabled) return false
        openSystem()
        return true
    }
    function close() { open = false }
    function toggle() { open ? close() : openSystem() }

    Component.onDestruction: if (open) K4System.stop()

    IpcHandler {
        target: "k4.system"
        function toggle(): void { root.toggle() }
        function open(): void { root.openSystem() }
        function close(): void { root.close() }
    }

    view: Component { K4SystemView { plugin: root } }
}
