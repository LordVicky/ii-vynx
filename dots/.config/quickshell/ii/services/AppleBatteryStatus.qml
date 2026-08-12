pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    // Stay completely idle unless the Battery widget explicitly enables the
    // Apple source. Remote battery readings only need a low polling cadence.
    readonly property bool enabled: Config.options.background.widgets.battery?.showAppleBatteries ?? false
    readonly property int refreshInterval: 15 * 60 * 1000
    readonly property int staleAfter: 30 * 60 * 1000
    readonly property int expireAfter: 2 * 60 * 60 * 1000
    property string state: "idle"
    property list<var> devices: []
    property double lastRefresh: 0
    property bool refreshing: false

    readonly property string helperPath: Quickshell.shellPath("scripts/apple/battery-status.py")

    function refresh() {
        if (!root.enabled || refreshProcess.running)
            return;
        root.refreshing = true;
        refreshProcess.running = true;
    }

    function age(observedAt) {
        if (!observedAt)
            return Number.POSITIVE_INFINITY;
        return Math.max(0, Date.now() - observedAt);
    }

    function isStale(device) {
        return root.age(device?.observedAt) >= root.staleAfter;
    }

    function isExpired(device) {
        return root.age(device?.observedAt) >= root.expireAfter;
    }

    onEnabledChanged: {
        if (root.enabled)
            root.refresh();
        else {
            root.state = "idle";
            root.devices = [];
            root.lastRefresh = 0;
        }
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.enabled
            && root.state !== "notConfigured"
            && root.state !== "authenticationRequired"
            && root.state !== "dependencyMissing"
        onTriggered: root.refresh()
    }

    Process {
        id: refreshProcess
        command: ["python3", root.helperPath, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.refreshing = false;
                if (!text.length) {
                    root.state = "error";
                    return;
                }

                try {
                    const payload = JSON.parse(text);
                    root.state = payload.state ?? "error";
                    if (root.state === "connected") {
                        root.devices = payload.devices ?? [];
                        root.lastRefresh = payload.observedAt ?? Date.now();
                    }
                    // Keep the last successful in-memory snapshot on temporary
                    // failures. BatteryDevices will age it out by observedAt.
                } catch (error) {
                    root.state = "error";
                    console.warn(`[AppleBatteryStatus] Invalid helper response: ${error.message}`);
                }
            }
        }
    }
}
