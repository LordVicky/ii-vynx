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

    // Control Center V2 keeps the supplied prototype's cooler desktop palette
    // local to Panel instead of changing every existing K4 utility surface.
    // The levels intentionally have wider luminance separation than the base
    // K4 surfaces so nested cards and controls remain legible at desktop scale.
    readonly property color panelSurface: "#111820"
    readonly property color panelSurfaceHi: "#1b2531"
    readonly property color panelSurfaceHot: "#273545"
    readonly property color panelTrack: "#33414f"
    readonly property color panelBlue: "#6ea8ff"
    readonly property color panelMuted: "#aab5c0"
    readonly property color panelDim: "#6e7a87"
    readonly property color panelInkSoft: "#e3e9ef"
    readonly property color panelLine: Qt.rgba(1, 1, 1, 0.09)
    readonly property color panelLineStrong: Qt.rgba(1, 1, 1, 0.14)

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
