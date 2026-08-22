pragma Singleton

import QtQuick
import Quickshell

// k4 visual tokens adapted from k4ditano/k4 at the pinned source commit.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Singleton {
    readonly property string uiFont: "Adwaita Sans"
    readonly property string iconFont: "MesloLGS Nerd Font Mono"

    readonly property color islandBg: "#000000"
    readonly property color ink: "#ffffff"
    readonly property color muted: "#8e8e93"
    readonly property color dim: "#48484a"
    readonly property color surface: "#1c1c1e"
    readonly property color surfaceHi: "#2c2c2e"
    readonly property color track: "#3a3a3c"
    readonly property color red: "#ff453a"

    readonly property int wing: 16
    readonly property int baseHeight: 34
    readonly property int maxIslandHeight: 880

    // Material Design Nerd Font glyphs used by K4-04 only.
    readonly property var ico: ({
        play: String.fromCodePoint(0xF040A),
        pause: String.fromCodePoint(0xF03E4),
        next: String.fromCodePoint(0xF04AD),
        prev: String.fromCodePoint(0xF04AE),
        shuffle: String.fromCodePoint(0xF049D),
        output: String.fromCodePoint(0xF0F5F),
        music: String.fromCodePoint(0xF0387),
        volHigh: String.fromCodePoint(0xF057E),
        volMed: String.fromCodePoint(0xF0580),
        volOff: String.fromCodePoint(0xF0581)
    })
}
