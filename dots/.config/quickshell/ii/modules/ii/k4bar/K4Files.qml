pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// K4-local file-search adapter. ii-vynx has no global file-index owner, so this
// keeps the pinned k4 on-demand fd model: one debounced process while queried,
// no background indexer or recurring poll.
Singleton {
    id: root

    readonly property string searchScript: Quickshell.shellRoot
        + "/modules/ii/k4bar/tools/k4-file-search.py"
    property string query: ""
    property string scope: "home"
    property string typeFilter: ""
    property var results: []
    property bool searching: false
    property int elapsedMs: 0

    onQueryChanged: debounce.restart()
    onScopeChanged: debounce.restart()
    onTypeFilterChanged: debounce.restart()

    Timer { id: debounce; interval: 160; onTriggered: root.runSearch() }

    function reset() {
        query = ""
        scope = "home"
        typeFilter = ""
        results = []
        searching = false
        searchProc.running = false
    }

    function runSearch() {
        const trimmed = query.trim()
        if (trimmed.length < 2) {
            results = []
            searching = false
            searchProc.running = false
            return
        }
        const command = ["python3", searchScript, trimmed, "--scope", scope, "--limit", "60"]
        if (typeFilter.length > 0) command.push("--type", typeFilter)
        searchProc.running = false
        searchProc.command = command
        searching = true
        searchProc.running = true
    }

    function openPath(path) { Quickshell.execDetached(["xdg-open", path]) }
    function openContaining(row) {
        if (!row) return
        Quickshell.execDetached(["xdg-open", row.directory])
    }
    function copyPath(path) {
        copyProc.command = ["bash", "-c", "printf %s " + shellQuote(path) + " | wl-copy"]
        copyProc.running = true
    }
    function shellQuote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    if (data.query !== root.query.trim()) return
                    root.results = data.results || []
                    root.elapsedMs = data.ms || 0
                } catch (error) {
                    root.results = []
                }
                root.searching = false
            }
        }
        onExited: function(code) {
            if (code !== 0)
                root.searching = false
        }
    }

    Process { id: copyProc }
}
