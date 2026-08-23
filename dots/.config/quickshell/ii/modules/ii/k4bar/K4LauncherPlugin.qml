import QtQuick
import Quickshell.Io
import qs.services

// Desktop-application launcher behavior adapted from k4ditano/k4 Launcher at
// the pinned source commit. Application discovery/launch ownership is delegated
// to ii-vynx through K4DesktopApps.
K4Plugin {
    id: root

    name: "launcher"
    title: "Launcher"
    priority: 80
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property string query: ""
    property int index: 0
    property var matches: []

    islandWidth: 720
    islandHeight: 440

    function rebuild(preserveSelection = false) {
        const results = K4DesktopApps.search(query)
        matches = results
        if (preserveSelection)
            index = Math.max(0, Math.min(index, results.length - 1))
        else
            index = 0
    }

    function toggle() {
        if (open) {
            close()
            return
        }
        openSearch("")
    }

    function openSearch(initial = "") {
        K4Panel.close()
        K4Notifications.dismissToast()
        query = String(initial || "")
        index = 0
        open = true
        rebuild()
    }

    // The ii-vynx island host already animates width/height to the next owner.
    // Keeping a synthetic closing owner here left a blank 720x440 island for
    // 320 ms before that animation could start, so release ownership at once.
    function close() {
        if (!open)
            return
        open = false
        query = ""
    }

    function yieldToNotification() {
        open = false
        query = ""
    }

    function launchSelected() {
        if (matches.length === 0 || index < 0 || index >= matches.length)
            return
        const entry = matches[index]
        close()
        K4DesktopApps.launch(entry)
    }

    function moveSelection(delta) {
        if (matches.length === 0)
            return
        index = Math.max(0, Math.min(matches.length - 1, index + delta))
    }

    Connections {
        target: Notifications
        function onNotify(notification) { root.yieldToNotification() }
    }

    Component.onCompleted: K4Launcher.plugin = root
    Component.onDestruction: {
        if (K4Launcher.plugin === root)
            K4Launcher.plugin = null
    }

    IpcHandler {
        target: "k4.launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.openSearch("") }
        function search(query: string): void { root.openSearch(query) }
        function close(): void { root.close() }
    }

    view: Component {
        K4LauncherView { plugin: root }
    }
}
