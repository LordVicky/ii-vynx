pragma Singleton

import QtQuick
import qs.services

// Presentation adapter only. Audio.qml remains ii-vynx's single PipeWire owner;
// this singleton translates that service for the K4 panel.
Singleton {
    id: root

    readonly property var outputs: Audio.outputDevices
    readonly property var inputs: Audio.inputDevices
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
