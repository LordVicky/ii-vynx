pragma Singleton

import QtQuick
import Quickshell
import qs.services

// k4 volume-HUD presentation state layered on ii-vynx's existing Audio owner.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Singleton {
    id: root

    readonly property var sink: Audio.sink

    property int volume: 0
    property bool muted: false
    property bool initialized: false
    property bool overlayOpen: false

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.syncFromSink()
        }

        function onMutedChanged() {
            root.syncFromSink()
        }
    }

    onSinkChanged: syncFromSink()
    Component.onCompleted: syncFromSink()

    function syncFromSink() {
        if (!sink || !sink.audio)
            return

        const nextVolume = Math.round(sink.audio.volume * 100)
        const nextMuted = !!sink.audio.muted
        const changed = initialized
            && (nextVolume !== volume || nextMuted !== muted)

        volume = nextVolume
        muted = nextMuted
        initialized = true

        if (changed)
            showOverlay()
    }

    function showOverlay() {
        overlayOpen = true
        overlayTimer.restart()
    }

    function setVolume(percent) {
        const bounded = Math.max(0, Math.min(100, Math.round(percent)))
        if (!sink || !sink.audio)
            return
        sink.audio.volume = bounded / 100
        sink.audio.muted = false
        volume = bounded
        muted = false
        showOverlay()
    }

    function toggleMute() {
        if (!sink || !sink.audio)
            return
        sink.audio.muted = !sink.audio.muted
        showOverlay()
    }

    Timer {
        id: overlayTimer
        interval: 1600
        onTriggered: root.overlayOpen = false
    }
}
