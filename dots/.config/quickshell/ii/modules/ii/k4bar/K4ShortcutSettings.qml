pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// Plugin-local persistence mirrors pinned k4's Settings ownership without
// broadening ii-vynx's global Config schema. The XDG state root is outside the
// rsync --delete deployment tree and respects a custom XDG_STATE_HOME.
Singleton {
    id: root

    readonly property string path: FileUtils.trimFileProtocol(
        `${Directories.state}/ii-vynx-k4-shortcuts.json`)
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
