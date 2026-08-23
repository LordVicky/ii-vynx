import QtQuick
import Quickshell.Io

// File-search utility adapted from k4ditano/k4 FilesPlugin at the pinned source
// commit. Search is on-demand through K4Files; no global indexer is introduced.
K4Plugin {
    id: root

    name: "files"
    title: "Files"
    priority: 81
    application: true
    applicationGlyph: String.fromCodePoint(0xF024B)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property int index: 0
    readonly property var entries: K4Files.results
    readonly property int count: entries.length

    islandWidth: 760
    islandHeight: 470

    function openFiles() {
        K4Panel.close()
        K4Notifications.dismissToast()
        K4Files.reset()
        index = 0
        open = true
    }

    function openApplication() {
        if (!enabled) return false
        openFiles()
        return true
    }

    function close() {
        if (!open) return
        open = false
        K4Files.reset()
        index = 0
    }

    function toggle() { open ? close() : openFiles() }
    function moveSelection(delta) {
        if (count === 0) return
        index = Math.max(0, Math.min(count - 1, index + delta))
    }
    function choose() {
        const row = entries[index]
        if (!row) return
        K4Files.openPath(row.path)
        close()
    }
    function openContaining() {
        const row = entries[index]
        if (!row) return
        K4Files.openContaining(row)
        close()
    }
    function copyPath() {
        const row = entries[index]
        if (row) K4Files.copyPath(row.path)
    }
    function toggleScope() {
        K4Files.scope = K4Files.scope === "home" ? "system" : "home"
        index = 0
    }
    function toggleType(type) {
        K4Files.typeFilter = K4Files.typeFilter === type ? "" : type
        index = 0
    }

    onCountChanged: if (index >= count) index = Math.max(0, count - 1)

    IpcHandler {
        target: "k4.files"
        function toggle(): void { root.toggle() }
        function open(): void { root.openFiles() }
        function close(): void { root.close() }
        function find(query: string): void {
            root.openFiles()
            K4Files.query = query
        }
    }

    view: Component { K4FilesView { plugin: root } }
}
