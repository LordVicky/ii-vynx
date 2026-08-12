pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Remote battery readings change slowly. One short-lived helper process per
    // interval keeps this service effectively idle between refreshes.
    readonly property int refreshInterval: 15 * 60 * 1000
    property string state: "idle"
    property list<var> devices: []
    property double lastRefresh: 0
    property bool refreshing: false

    readonly property string helperPath: Quickshell.shellPath("scripts/apple/battery-status.py")

    function refresh() {
        if (refreshProcess.running)
            return;
        root.refreshing = true;
        refreshProcess.running = true;
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.state !== "notConfigured" && root.state !== "authenticationRequired"
        onTriggered: root.refresh()
    }

    Process {
        id: refreshProcess
        command: ["python3", root.helperPath, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.refreshing = false;
                if (!text.length)
                    return;

                try {
                    const payload = JSON.parse(text);
                    root.state = payload.state ?? "error";
                    if (root.state === "connected") {
                        root.devices = payload.devices ?? [];
                        root.lastRefresh = payload.observedAt ?? Date.now();
                    }
                } catch (error) {
                    root.state = "error";
                    console.warn(`[AppleBatteryStatus] Invalid helper response: ${error.message}`);
                }
            }
        }
    }
}
