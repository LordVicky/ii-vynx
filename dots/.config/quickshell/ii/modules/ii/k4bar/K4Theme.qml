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
    readonly property color blue: "#0a84ff"
    readonly property color green: "#30d158"
    readonly property color yellow: "#ffd60a"

    // Control Center V2 follows the OLED-black K4 island rather than introducing
    // a separate blue-grey dashboard. Nested surfaces stay neutral and use
    // luminance/borders for hierarchy; blue is reserved for active state.
    readonly property color panelSurface: "#050505"
    readonly property color panelSurfaceHi: "#111113"
    readonly property color panelSurfaceHot: "#1a1a1d"
    readonly property color panelTrack: "#2a2a2e"
    readonly property color panelBlue: "#0a84ff"
    readonly property color panelMuted: "#a1a1a6"
    readonly property color panelDim: "#636366"
    readonly property color panelInkSoft: "#f2f2f7"
    readonly property color panelLine: Qt.rgba(1, 1, 1, 0.08)
    readonly property color panelLineStrong: Qt.rgba(1, 1, 1, 0.15)

    readonly property int wing: 16
    readonly property int baseHeight: 34
    readonly property int maxIslandHeight: 880

    // Material Design Nerd Font glyphs used by K4 built-ins.
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
        volOff: String.fromCodePoint(0xF0581),
        bell: String.fromCodePoint(0xF009A),
        bellOutline: String.fromCodePoint(0xF009C),
        close: String.fromCodePoint(0xF0156),
        clearAll: String.fromCodePoint(0xF039F),
        back: String.fromCodePoint(0xF0141),
        forward: String.fromCodePoint(0xF0142),
        chevronUp: String.fromCodePoint(0xF0143),
        wifi: String.fromCodePoint(0xF05A9),
        wifiOff: String.fromCodePoint(0xF092E),
        bluetooth: String.fromCodePoint(0xF00AF),
        bluetoothOff: String.fromCodePoint(0xF00B2),
        lock: String.fromCodePoint(0xF033E),
        check: String.fromCodePoint(0xF012C),
        grid: String.fromCodePoint(0xF02C1),
        speaker: String.fromCodePoint(0xF057E),
        microphone: String.fromCodePoint(0xF036C)
    })
}
