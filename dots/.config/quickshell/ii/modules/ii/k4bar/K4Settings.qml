pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// K4 settings adapter. Persistence stays in ii-vynx Config; this singleton is
// only the narrow K4-facing contract used by the in-island settings view.
Singleton {
    id: root

    // Temporary K4-11 prototype harness. It is intentionally isolated from
    // plugin metadata, arbitration and persisted enablement; the only purpose
    // is to validate Qt-owned Loader lifetime for a non-visual K4Plugin.
    property var lifecycleProbeHost: K4PluginLifecycleProbeHost {}

    readonly property string position: Config.options.bar.k4.position
    readonly property int alignment: Config.options.bar.k4.alignment
    readonly property string spaceMode: Config.options.bar.k4.spaceMode
    readonly property bool trayInPill: Config.options.bar.k4.trayInPill
    readonly property bool notificationsOnHover: Config.options.bar.k4.notificationsOnHover
    readonly property bool dismissNotificationsOnFocus: Config.options.bar.k4.dismissNotificationsOnFocus
    readonly property var disabledPlugins: Config.options.bar.k4.disabledPlugins

    readonly property var positions: [
        { label: "Top", value: "top" },
        { label: "Bottom", value: "bottom" }
    ]
    readonly property var alignments: [
        { label: "Left", value: 15 },
        { label: "Center", value: 50 },
        { label: "Right", value: 85 }
    ]
    readonly property var spaceModes: [
        { label: "Reserve space", value: "reserve" },
        { label: "Away when fullscreen", value: "fullscreen" },
        { label: "On top", value: "overlay" },
        { label: "Hidden", value: "hidden" }
    ]

    function isProtectedPlugin(name) {
        const id = String(name)
        return id === "idle" || id === "settings" || id === "panel" || id === "apps"
    }

    function setPosition(wanted) {
        const value = String(wanted)
        if (value === "top" || value === "bottom")
            Config.options.bar.k4.position = value
    }

    function setAlignment(wanted) {
        const value = Number(wanted)
        if (value === 15 || value === 50 || value === 85)
            Config.options.bar.k4.alignment = value
    }

    function setSpaceMode(wanted) {
        const value = String(wanted)
        if (["reserve", "fullscreen", "overlay", "hidden"].indexOf(value) >= 0)
            Config.options.bar.k4.spaceMode = value
    }

    function setTrayInPill(wanted) {
        Config.options.bar.k4.trayInPill = Boolean(wanted)
    }

    function setNotificationsOnHover(wanted) {
        Config.options.bar.k4.notificationsOnHover = Boolean(wanted)
    }

    function setDismissNotificationsOnFocus(wanted) {
        Config.options.bar.k4.dismissNotificationsOnFocus = Boolean(wanted)
    }

    function pluginEnabled(name) {
        const id = String(name)
        if (isProtectedPlugin(id))
            return true
        return disabledPlugins.indexOf(id) < 0
    }

    function setPluginEnabled(name, wanted) {
        const id = String(name)
        if (isProtectedPlugin(id))
            return

        const next = disabledPlugins.slice()
        const index = next.indexOf(id)
        if (Boolean(wanted)) {
            if (index >= 0)
                next.splice(index, 1)
        } else if (index < 0) {
            next.push(id)
        }
        Config.options.bar.k4.disabledPlugins = next
    }
}
