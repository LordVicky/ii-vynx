pragma Singleton

import QtQuick
import qs.services

// Presentation adapter only. Network.qml remains the single nmcli owner.
Singleton {
    id: root

    readonly property bool enabled: Network.wifiEnabled
    readonly property bool scanning: Network.wifiScanning
    readonly property bool connecting: Network.wifiConnecting
    readonly property var connectTarget: Network.wifiConnectTarget
    readonly property var networks: Network.friendlyWifiNetworks
    readonly property var active: Network.active
    readonly property string name: Network.networkName
    readonly property string statusText: Network.wifiStatus
    readonly property var passwordTarget: networks.find(network => network.askingPassword) ?? null
    property string password: ""

    function toggle() {
        Network.toggleWifi()
    }

    function scan() {
        Network.rescanWifi()
    }

    function activate(network) {
        if (!network)
            return
        if (network.active)
            Network.disconnectWifiNetwork()
        else
            Network.connectToWifiNetwork(network)
    }

    function submitPassword() {
        if (!passwordTarget || password.length === 0)
            return
        Network.changePassword(passwordTarget, password)
        password = ""
    }

    function cancelPassword() {
        if (passwordTarget)
            passwordTarget.askingPassword = false
        password = ""
    }

    function openPortal() {
        Network.openPublicWifiPortal()
    }

    function strengthGlyph(network) {
        const strength = network?.strength ?? 0
        if (strength > 80) return "󰤨"
        if (strength > 60) return "󰤥"
        if (strength > 40) return "󰤢"
        if (strength > 20) return "󰤟"
        return "󰤯"
    }
}
