import QtQuick
import Quickshell.Io
import qs.services

// Desktop-application launcher behavior adapted from k4ditano/k4 Launcher at
// the pinned source commit. Application discovery/launch ownership stays in
// ii-vynx through K4DesktopApps; package search delegates to pacman/yay only
// while package mode is active.
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
    property string mode: "apps"

    readonly property var packageMatches: K4Packages.matches
    readonly property bool aurSearching: K4Packages.aurSearching
    readonly property int count: mode === "packages" ? packageMatches.length : matches.length

    islandWidth: 720
    islandHeight: 440

    function installEntry() {
        const trimmed = query.trim()
        if (!trimmed.length) return null
        return {
            isInstall: true,
            name: `Install “${trimmed}”`,
            genericName: "Search official repositories and AUR",
            icon: ""
        }
    }

    function rebuild(preserveSelection = false) {
        if (mode !== "apps") return

        const results = K4DesktopApps.search(query).slice()
        const install = installEntry()
        if (install) {
            const q = query.trim().toLowerCase()
            const triggered = "install".indexOf(q) === 0 || "instalar".indexOf(q) === 0
            if (triggered) results.unshift(install)
            else results.push(install)
        }

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
        mode = "apps"
        K4Packages.reset()
        query = String(initial || "")
        index = 0
        open = true
        rebuild()
    }

    function openPackageSearch(initial = "") {
        K4Panel.close()
        K4Notifications.dismissToast()
        query = String(initial || "")
        index = 0
        mode = "packages"
        open = true
        K4Packages.open(query)
    }

    function enterPackageMode() {
        mode = "packages"
        index = 0
        K4Packages.open(query)
    }

    function leavePackageMode() {
        K4Packages.reset()
        mode = "apps"
        index = 0
        rebuild()
    }

    function schedulePackageSearch() {
        index = 0
        K4Packages.search(query)
    }

    // The ii-vynx island host already animates width/height to the next owner.
    // Release ownership immediately; K4Packages also stops in-flight searches.
    function close() {
        if (!open)
            return
        open = false
        query = ""
        mode = "apps"
        K4Packages.reset()
    }

    function yieldToNotification() {
        open = false
        query = ""
        mode = "apps"
        K4Packages.reset()
    }

    function launchSelected() {
        if (mode === "packages") {
            const pkg = packageMatches[index]
            if (!pkg) return
            close()
            K4Packages.install(pkg)
            return
        }

        if (matches.length === 0 || index < 0 || index >= matches.length)
            return
        const entry = matches[index]
        if (entry && entry.isInstall === true) {
            enterPackageMode()
            return
        }
        close()
        K4DesktopApps.launch(entry)
    }

    function uninstallPackage(pkg) {
        if (!pkg || pkg.installed !== true) return
        close()
        K4Packages.uninstall(pkg)
    }

    function uninstallSelected() {
        if (mode !== "packages") return
        uninstallPackage(packageMatches[index])
    }

    function moveSelection(delta) {
        if (count === 0)
            return
        index = Math.max(0, Math.min(count - 1, index + delta))
    }

    Connections {
        target: Notifications
        function onNotify(notification) { root.yieldToNotification() }
    }

    Connections {
        target: K4Packages
        function onMatchesChanged() {
            if (root.mode !== "packages") return
            root.index = Math.max(0, Math.min(root.index, K4Packages.matches.length - 1))
        }
    }

    Component.onCompleted: K4Launcher.plugin = root
    Component.onDestruction: {
        K4Packages.reset()
        if (K4Launcher.plugin === root)
            K4Launcher.plugin = null
    }

    IpcHandler {
        target: "k4.launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.openSearch("") }
        function search(query: string): void { root.openSearch(query) }
        function install(query: string): void { root.openPackageSearch(query) }
        function close(): void { root.close() }
    }

    view: Component {
        K4LauncherView { plugin: root }
    }
}
