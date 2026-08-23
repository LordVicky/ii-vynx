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

    function toggle() {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
    }

    function setDiscovering(wanted) {
        if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)
            Bluetooth.defaultAdapter.discovering = wanted
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
