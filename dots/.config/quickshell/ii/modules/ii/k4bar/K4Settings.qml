pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// K4 settings adapter. Persistence stays in ii-vynx Config; this singleton is
// only the narrow K4-facing contract used by the in-island settings view.
Singleton {
    id: root

    readonly property string position: Config.options.bar.k4.position
    readonly property int alignment: Config.options.bar.k4.alignment
    readonly property string spaceMode: Config.options.bar.k4.spaceMode
    readonly property bool trayInPill: Config.options.bar.k4.trayInPill
    readonly property bool notificationsOnHover: Config.options.bar.k4.notificationsOnHover
    readonly property bool dismissNotificationsOnFocus: Config.options.bar.k4.dismissNotificationsOnFocus
    readonly property bool playerPeekOnTrackChange: Config.options.bar.k4.playerPeekOnTrackChange

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

    function setPlayerPeekOnTrackChange(wanted) {
        Config.options.bar.k4.playerPeekOnTrackChange = Boolean(wanted)
    }
}
