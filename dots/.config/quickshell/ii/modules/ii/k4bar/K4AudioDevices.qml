pragma Singleton

import QtQuick
import Quickshell
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

    function normalizedBluetoothAddress(value) {
        return String(value || "").toUpperCase().replace(/[^0-9A-F]/g, "")
    }

    function bluetoothDeviceFor(node) {
        if (!node)
            return null

        const nodeName = String(node.name || "")
        if (nodeName.indexOf("bluez_") !== 0)
            return null

        const addressMatch = nodeName.match(/([0-9A-Fa-f]{2}(?:[_:-][0-9A-Fa-f]{2}){5})/)
        const nodeAddress = addressMatch
            ? root.normalizedBluetoothAddress(addressMatch[1]) : ""
        const friendlyName = Audio.friendlyDeviceName(node)
        const devices = BluetoothStatus.friendlyDeviceList

        for (let i = 0; i < devices.length; ++i) {
            const device = devices[i]
            if (!device.connected)
                continue

            const deviceAddress = root.normalizedBluetoothAddress(device.address)
            if (nodeAddress.length > 0 && deviceAddress === nodeAddress)
                return device
        }

        // Keep a display-name fallback for BlueZ/PipeWire variants that do not
        // expose the hardware address in the node name.
        for (let i = 0; i < devices.length; ++i) {
            const device = devices[i]
            if (device.connected && String(device.name || "") === friendlyName)
                return device
        }

        return null
    }

    function bluetoothBatteryPercentFor(node) {
        const bluetoothDevice = root.bluetoothDeviceFor(node)
        if (!bluetoothDevice?.batteryAvailable)
            return -1
        return Math.round(bluetoothDevice.battery * 100)
    }

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
