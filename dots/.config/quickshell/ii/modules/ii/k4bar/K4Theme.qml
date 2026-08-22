pragma Singleton

import QtQuick
import Quickshell

// k4 visual tokens adapted from k4ditano/k4 at the pinned source commit.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Singleton {
    readonly property string uiFont: "Adwaita Sans"

    readonly property color islandBg: "#000000"
    readonly property color ink: "#ffffff"
    readonly property color muted: "#8e8e93"
    readonly property color surface: "#1c1c1e"
    readonly property color track: "#3a3a3c"
    readonly property color red: "#ff453a"

    readonly property int wing: 16
    readonly property int baseHeight: 34
    readonly property int maxIslandHeight: 880
}
