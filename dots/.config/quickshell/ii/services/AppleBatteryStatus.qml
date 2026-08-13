pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // One cheap probe on shell start; if Apple is not configured, polling stops.
    // Once configured, refresh remotely at a deliberately low cadence.
    readonly property int refreshInterval: 15 * 60 * 1000
    readonly property int errorRetryInterval: 30 * 60 * 1000
    readonly property int staleAfter: 30 * 60 * 1000
    readonly property int expireAfter: 2 * 60 * 60 * 1000

    property string state: "idle"
    property list<var> devices: []
    property double lastRefresh: 0
    property double lastAttempt: 0
    property bool refreshing: false

    readonly property string helperPath: Quickshell.shellPath("scripts/apple/battery-status.py")

    function refresh() {
        if (refreshProcess.running)
            return;
        root.refreshing = true;
        refreshProcess.running = true;
    }

    function age(observedAt) {
        if (!observedAt)
            return Number.POSITIVE_INFINITY;
        return Math.max(0, root.lastAttempt - observedAt);
    }

    function isStale(device) {
        return root.age(device?.observedAt) >= root.staleAfter;
    }

    function isExpired(device) {
        return root.age(device?.observedAt) >= root.expireAfter;
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: root.state === "error" ? root.errorRetryInterval : root.refreshInterval
        repeat: true
        running: root.state === "connected" || root.state === "error"
        onTriggered: root.refresh()
    }

    Process {
        id: refreshProcess
        command: ["python3", root.helperPath, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.refreshing = false;
                root.lastAttempt = Date.now();

                if (!text.length) {
                    root.state = "error";
                    return;
                }

                try {
                    const payload = JSON.parse(text);
                    root.state = payload.state ?? "error";
                    if (root.state === "connected") {
                        root.devices = payload.devices ?? [];
                        root.lastRefresh = payload.observedAt ?? root.lastAttempt;
                    }
                    // Preserve the last successful in-memory snapshot on
                    // transient errors. Consumers age it using lastAttempt.
                } catch (error) {
                    root.state = "error";
                    console.warn(`[AppleBatteryStatus] Invalid helper response: ${error.message}`);
                }
            }
        }
    }
}
