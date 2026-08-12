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

    onEnabledChanged: {
        if (root.enabled)
            root.refresh();
        else
            root.devices = [];
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.enabled
            && root.state !== "notConfigured"
            && root.state !== "authenticationRequired"
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
