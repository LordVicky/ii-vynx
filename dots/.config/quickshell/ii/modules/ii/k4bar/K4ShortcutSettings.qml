pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Plugin-local persistence mirrors pinned k4's Settings ownership without
// broadening ii-vynx's global Config schema. The parent ~/.local/state exists
// on a normal desktop and is outside the rsync --delete deployment tree.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/state/ii-vynx-k4-shortcuts.json"
    property alias shortcuts: adapter.shortcuts

    function setShortcuts(values) {
        adapter.shortcuts = values
    }

    FileView {
        id: stateFile
        path: root.path
        watchChanges: true
        onAdapterUpdated: writeAdapter()
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: adapter
            property var shortcuts: ["game", "hyprtheme", "system", "clipboard"]
        }
    }
}
