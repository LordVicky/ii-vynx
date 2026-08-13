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

    function mergeDevices(nextDevices) {
        const next = nextDevices ?? [];
        const merged = [];
        const seen = {};

        for (let i = 0; i < next.length; ++i) {
            const device = next[i];
            if (!device?.id)
                continue;
            seen[device.id] = true;
            merged.push(device);
        }

        // Find My may omit a sleeping/offline device from one successful
        // response. Keep the previous observation until its normal expiry.
        for (let i = 0; i < root.devices.length; ++i) {
            const device = root.devices[i];
            if (!device?.id || seen[device.id] || root.isExpired(device))
                continue;
            merged.push(device);
        }

        return merged;
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

        // During development, pyicloud lives in a dedicated venv rather than
        // Fedora's system Python. Prefer the eventual production venv, fall
        // back to the Phase 4 validation venv, then finally system python3.
        command: [
            "sh",
            "-c",
            'if [ -x "$HOME/.local/share/ii-vynx/apple-venv/bin/python" ]; then exec "$HOME/.local/share/ii-vynx/apple-venv/bin/python" "$1" status; elif [ -x "$HOME/.local/share/ii-vynx/apple-test-venv/bin/python" ]; then exec "$HOME/.local/share/ii-vynx/apple-test-venv/bin/python" "$1" status; else exec python3 "$1" status; fi',
            "vynx-apple-battery",
            root.helperPath
        ]

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
                        root.devices = root.mergeDevices(payload.devices);
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
