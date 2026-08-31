pragma Singleton

import QtQuick
import Quickshell
import qs.services

// K4 shortcut presentation adapter. ii-vynx HyprlandKeybinds remains the only
// keybind reader; this layer only normalizes its live data for the K4 view.
Singleton {
    id: root

    readonly property var entries: normalize(HyprlandKeybinds.keybinds)
    readonly property int count: entries.length

    function modifiers(mask) {
        const out = []
        if (mask & (1 << 2)) out.push("Ctrl")
        if (mask & (1 << 6)) out.push("Super")
        if (mask & (1 << 0)) out.push("Shift")
        if (mask & (1 << 3)) out.push("Alt")
        if (mask & (1 << 1)) out.push("Caps")
        if (mask & (1 << 4)) out.push("Mod2")
        if (mask & (1 << 5)) out.push("Mod3")
        if (mask & (1 << 7)) out.push("Mod5")
        return out
    }

    function prettyKey(key) {
        const raw = String(key || "")
        const map = ({
            "RETURN": "Enter", "Return": "Enter", "SPACE": "Space",
            "ESCAPE": "Esc", "Escape": "Esc", "BACKSPACE": "Backspace",
            "SUPER_L": "Super", "SUPER_R": "Super", "mouse_up": "Scroll Up",
            "mouse_down": "Scroll Down", "mouse:272": "LMB", "mouse:273": "RMB"
        })
        return map[raw] || raw
    }

    function category(description) {
        const text = String(description || "")
        const index = text.indexOf(":")
        return index > 0 ? text.substring(0, index).trim() : "Uncategorized"
    }

    function action(description) {
        const text = String(description || "")
        const index = text.indexOf(":")
        return index > 0 ? text.substring(index + 1).trim() : text.trim()
    }

    function normalize(raws) {
        const out = []
        for (let i = 0; i < raws.length; ++i) {
            const bind = raws[i]
            if (!bind || !String(bind.description || "").trim()) continue
            const parts = modifiers(Number(bind.modmask || 0))
            const key = prettyKey(bind.key)
            if (key.length > 0 && parts.indexOf(key) < 0) parts.push(key)
            out.push({ combo: parts.join(" + "), section: category(bind.description), action: action(bind.description) })
        }
        return out
    }

    function filter(query) {
        const q = String(query || "").trim().toLowerCase()
        if (!q.length) return entries
        return entries.filter(entry => `${entry.combo} ${entry.section} ${entry.action}`.toLowerCase().indexOf(q) >= 0)
    }

    function keys(combo) {
        return String(combo || "").split("+").map(part => part.trim()).filter(part => part.length > 0)
    }
}
