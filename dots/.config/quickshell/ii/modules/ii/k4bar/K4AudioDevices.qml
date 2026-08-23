pragma Singleton

import QtQuick
import qs.services

// Presentation adapter only. Audio.qml remains ii-vynx's single PipeWire owner;
// this singleton translates that service for the K4 panel.
Singleton {
    id: root

    function isPanelDevice(node) {
        if (!node || node.isStream)
            return false
        const name = String(node.name || "")
        if (name.indexOf("alsa_") === 0)
            return true
        return name.indexOf("bluez_") === 0 && name.indexOf("midi") < 0
    }

    // Use raw candidates here: non-default nodes may not expose node.audio until
    // K4PanelAudioView's scoped PwObjectTracker observes them.
    readonly property var outputs: Audio.outputDeviceCandidates.filter(root.isPanelDevice)
    readonly property var inputs: Audio.inputDeviceCandidates.filter(root.isPanelDevice)
    readonly property var activeOutput: Audio.sink
    readonly property var activeInput: Audio.source

    function nameFor(node) {
        return node ? Audio.friendlyDeviceName(node) : ""
    }

    function selectOutput(node) {
        if (node)
            Audio.setDefaultSink(node)
    }

    function selectInput(node) {
        if (node)
            Audio.setDefaultSource(node)
    }

    function volumeFor(node) {
        return node?.audio ? Math.round(node.audio.volume * 100) : 0
    }

    function setVolume(node, percent) {
        if (!node?.audio)
            return
        node.audio.volume = Math.max(0, Math.min(150, Math.round(percent))) / 100
    }

    function mutedFor(node) {
        return node?.audio?.muted ?? false
    }

    function toggleMute(node) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted
    }

    function baseFor(node) {
        return Audio.baseVolumeFor(node)
    }

    function dbOverNatural(node) {
        return Audio.dbOverNatural(node)
    }
}
