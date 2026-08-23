pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

// K4 clipboard presentation adapter. ii-vynx Cliphist remains the single
// clipboard-history owner; this layer only normalizes rows and persists K4 pin
// ordering. It deliberately starts no wl-paste watcher or cliphist process.
Singleton {
    id: root

    readonly property string statePath: FileUtils.trimFileProtocol(
        `${Directories.state}/ii-vynx-k4-clipboard.json`)
    property alias pinnedIds: adapter.pinnedIds
    readonly property int count: Cliphist.entries.length

    function entryId(raw) {
        const text = String(raw || "")
        const tab = text.indexOf("\t")
        return tab >= 0 ? text.substring(0, tab) : text
    }

    function summary(raw) {
        const text = String(raw || "")
        const tab = text.indexOf("\t")
        return (tab >= 0 ? text.substring(tab + 1) : text).trim()
    }

    function classify(text) {
        const value = String(text || "").trim()
        if (/^https?:\/\//i.test(value)) return "link"
        if (/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(value)) return "color"
        if (/^(\/|~\/)/.test(value)) return "path"
        if (/^(sudo\s+|git\s+|pacman\s+|yay\s+|systemctl\s+|hyprctl\s+)/.test(value)) return "command"
        if (/[{}();]|=>|\b(function|const|let|var|class|import)\b/.test(value)) return "code"
        return "text"
    }

    function normalize(raw) {
        const text = summary(raw)
        return {
            raw: raw,
            id: entryId(raw),
            summary: text,
            label: classify(text),
            type: Cliphist.entryIsImage(raw) ? "image" : "text",
            lines: Math.max(1, text.split("\n").length),
            pinned: pinnedIds.indexOf(entryId(raw)) >= 0
        }
    }

    function filter(query) {
        const raws = Cliphist.fuzzyQuery(String(query || ""))
        const rows = raws.map(raw => normalize(raw))
        return rows.sort((a, b) => {
            if (a.pinned !== b.pinned) return a.pinned ? -1 : 1
            const ap = pinnedIds.indexOf(a.id)
            const bp = pinnedIds.indexOf(b.id)
            if (a.pinned && b.pinned && ap !== bp) return ap - bp
            return 0
        })
    }

    function refresh() { Cliphist.refresh() }
    function copy(row) { if (row) Cliphist.copy(row.raw) }
    function remove(row) { if (row) Cliphist.deleteEntry(row.raw) }
    function clear() { Cliphist.wipe() }

    function togglePin(row) {
        if (!row) return
        const id = row.id
        const next = pinnedIds.slice()
        const index = next.indexOf(id)
        if (index >= 0) next.splice(index, 1)
        else next.unshift(id)
        adapter.pinnedIds = next
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onAdapterUpdated: writeAdapter()
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: adapter
            property var pinnedIds: []
        }
    }
}
