pragma Singleton

import QtQuick
import Quickshell
import qs.services

// System-monitor adapter over ii-vynx's demand-driven resource owners. The K4
// view contributes consumers only while open; it does not poll /proc itself.
Singleton {
    id: root
    property int consumers: 0

    readonly property real cpu: ResourceUsage.cpuUsage
    readonly property real memory: ResourceUsage.memoryUsedPercentage
    readonly property real swap: ResourceUsage.swapUsedPercentage
    readonly property real disk: ResourceUsage.diskUsedPercentage
    readonly property string cpuModel: ResourceUsage.cpuModel
    readonly property string cpuFreq: ResourceUsage.cpuFreq
    readonly property string cpuTemp: ResourceUsage.cpuTemp
    readonly property string memoryUsed: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)
    readonly property string memoryTotal: ResourceUsage.kbToGbString(ResourceUsage.memoryTotal)
    readonly property real download: NetworkUsage.networkDownloadSpeed
    readonly property real upload: NetworkUsage.networkUploadSpeed
    readonly property string hostname: SystemInfo.hostname
    readonly property string distro: SystemInfo.distroName

    function start() {
        consumers += 1
        if (consumers !== 1) return
        ResourceUsage.registerOverlayResourceConsumer()
        NetworkUsage.activeInstances += 1
    }

    function stop() {
        if (consumers <= 0) return
        consumers -= 1
        if (consumers !== 0) return
        ResourceUsage.unregisterOverlayResourceConsumer()
        NetworkUsage.activeInstances = Math.max(0, NetworkUsage.activeInstances - 1)
    }

    function formatRate(bytes) {
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB/s"
        if (bytes >= 1024) return Math.round(bytes / 1024) + " KB/s"
        return Math.round(bytes) + " B/s"
    }
}
