pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions

// Session-action presentation adapter. ii-vynx Session remains the single
// owner for lock/suspend/logout/power actions; K4 only selects and confirms
// those existing actions. Availability probing stays local and read-only.
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
            Session.lock()
            break
        case "suspend":
            Session.suspend()
            break
        case "hibernate":
            Session.hibernate()
            break
        case "logout":
            Session.logout()
            break
        case "reboot":
            Session.reboot()
            break
        case "poweroff":
            Session.poweroff()
            break
        }
    }

    FileView { id: powerState; path: "/sys/power/state" }
}
