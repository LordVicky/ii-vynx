pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services

// Presentation adapter only. Quickshell.Bluetooth remains the device owner and
// BluetoothStatus keeps ii's established ordering/status seam.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: BluetoothStatus.available
    readonly property bool enabled: BluetoothStatus.enabled
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var devices: BluetoothStatus.friendlyDeviceList

    // Discovery is shared adapter state. Only stop a scan that this K4 adapter
    // explicitly started; opening ordinary Control Center tabs must never send
    // an unsolicited StopDiscovery request to BlueZ.
    property bool ownsDiscovery: false
    property var discoveryAdapter: null

    function toggle() {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
    }

    function setDiscovering(wanted) {
        const target = Boolean(wanted)
        const current = Bluetooth.defaultAdapter

        if (target) {
            if (!current || !current.enabled || ownsDiscovery)
                return

            // If another owner already has discovery active, observe that scan
            // without claiming it. K4 must not stop somebody else's discovery
            // when the Bluetooth detail closes.
            if (current.discovering === target)
                return

            ownsDiscovery = true
            discoveryAdapter = current
            current.discovering = target
            return
        }

        if (!ownsDiscovery)
            return

        const owner = discoveryAdapter
        ownsDiscovery = false
        discoveryAdapter = null
        if (owner && owner.enabled)
            owner.discovering = target
    }

    function activate(device) {
        if (!device)
            return
        if (device.connected)
            device.disconnect()
        else
            device.connect()
    }

    function togglePair(device) {
        if (!device)
            return
        if (device.paired)
            device.forget()
        else
            device.pair()
    }

    function status(device) {
        if (!device)
            return ""
        let result = device.connected ? "Connected" : device.paired ? "Paired" : "Available"
        if (device.batteryAvailable)
            result += ` · ${Math.round(device.battery * 100)}%`
        return result
    }
}
