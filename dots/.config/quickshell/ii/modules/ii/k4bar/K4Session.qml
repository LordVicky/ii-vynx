pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Session-action adapter. The existing ii-vynx Lock remains the sole
// ext-session-lock owner; K4 only toggles GlobalStates.screenLocked and invokes
// the same compositor/system facilities for explicit session actions.
Singleton {
    id: root

    readonly property bool hibernateAvailable: powerState.text().split(/\s+/).includes("disk")

    readonly property var actions: {
        const rows = [
            { key: "lock", label: "Lock", glyph: String.fromCodePoint(0xF033E), tone: K4Theme.blue, confirm: false },
            { key: "suspend", label: "Suspend", glyph: String.fromCodePoint(0xF04B2), tone: K4Theme.blue, confirm: false }
        ]
        if (hibernateAvailable)
            rows.push({ key: "hibernate", label: "Hibernate", glyph: String.fromCodePoint(0xF0904), tone: K4Theme.blue, confirm: true })
        rows.push({ key: "logout", label: "Log out", glyph: String.fromCodePoint(0xF0343), tone: K4Theme.muted, confirm: true })
        rows.push({ key: "reboot", label: "Restart", glyph: String.fromCodePoint(0xF0709), tone: K4Theme.muted, confirm: true })
        rows.push({ key: "poweroff", label: "Power off", glyph: String.fromCodePoint(0xF0425), tone: K4Theme.red, confirm: true })
        return rows
    }

    function run(key) {
        switch (key) {
        case "lock":
            GlobalStates.screenLocked = true
            break
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend"])
            break
        case "hibernate":
            Quickshell.execDetached(["systemctl", "hibernate"])
            break
        case "logout":
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
            break
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"])
            break
        case "poweroff":
            Quickshell.execDetached(["systemctl", "poweroff"])
            break
        }
    }

    FileView { id: powerState; path: "/sys/power/state" }
}
