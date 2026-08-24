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

    readonly property var positions: [
        { label: "Top", value: "top" },
        { label: "Bottom", value: "bottom" }
    ]
    readonly property var alignments: [
        { label: "Left", value: 15 },
        { label: "Center", value: 50 },
        { label: "Right", value: 85 }
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
}
