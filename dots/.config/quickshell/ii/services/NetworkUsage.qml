pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "NetworkUsageMath.js" as NetworkUsageMath

Singleton {
    id: root
    
    property real networkDownloadSpeed: 0
    property real networkUploadSpeed: 0
    property real networkTotalSpeed: 0
    property real networkDownloadTotal: 0
    property real networkUploadTotal: 0
    
    property var previousNetworkStats: null

    property int activeInstances: 0
    property int resourceWidgetInstances: 0

    // Noise threshold: ignore speeds below 10 bytes/s to prevent flicker
    readonly property real noiseThreshold: 10

    Timer {
        id: timer
        interval: root.resourceWidgetInstances > 0
            ? (Config.options.background.widgets.resources.pollingInterval ?? 3000)
            : Config.options.bar.networkSpeed.updateInterval
        running: activeInstances > 0
        repeat: true
        onTriggered: {
            fileNetDev.reload()
            const netLines = fileNetDev.text().split('\n')
            let totalRx = 0, totalTx = 0
            
            // Typical lines: interface: rx_bytes ... tx_bytes ...
            for (let i = 2; i < netLines.length; i++) {
                const line = netLines[i].trim()
                if (line === "") continue
                
                // Monitor common interfaces (en*, wl*, eth*)
                if (line.startsWith('en') || line.startsWith('wl') || line.startsWith('eth')) {
                    const cols = line.split(/[:\s]+/)
                    if (cols.length >= 10) {
                        totalRx += Number(cols[1]) || 0
                        totalTx += Number(cols[9]) || 0
                    }
                }
            }
            
            if (root.previousNetworkStats !== null) {
                const secs = timer.interval / 1000.0
                const speeds = NetworkUsageMath.calculateSpeeds(
                    totalRx,
                    totalTx,
                    root.previousNetworkStats,
                    secs,
                    root.noiseThreshold
                )
                root.networkDownloadSpeed = speeds.download
                root.networkUploadSpeed = speeds.upload
                root.networkTotalSpeed = speeds.total
            }
            
            root.networkDownloadTotal = totalRx
            root.networkUploadTotal = totalTx
            root.previousNetworkStats = { rx: totalRx, tx: totalTx }
        }
    }

    FileView { id: fileNetDev; path: "/proc/net/dev" }
}
