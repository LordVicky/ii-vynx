pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property int pollingMinutes: 15
    readonly property int refreshInterval: root.pollingMinutes * 60 * 1000
    readonly property int errorRetryInterval: Math.max(30 * 60 * 1000, root.refreshInterval * 2)
    readonly property int staleAfter: Math.max(30 * 60 * 1000, root.refreshInterval * 2)
    readonly property int expireAfter: Math.max(2 * 60 * 60 * 1000, root.refreshInterval * 8)

    property string state: "idle"
    property list<var> devices: []
    property double lastRefresh: 0
    property double lastAttempt: 0
    property bool refreshing: false
    property bool disconnecting: false
    property bool savingPollingInterval: false

    readonly property string helperPath: Quickshell.shellPath("scripts/apple/battery-status.py")

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\\"'\\\"'") + "'";
    }

    function runtimePythonShell() {
        return 'if [ -x "$HOME/.local/share/ii-vynx/apple-venv/bin/python" ]; then PY="$HOME/.local/share/ii-vynx/apple-venv/bin/python"; '
            + 'elif [ -x "$HOME/.local/share/ii-vynx/apple-test-venv/bin/python" ]; then PY="$HOME/.local/share/ii-vynx/apple-test-venv/bin/python"; '
            + 'else PY=python3; fi;';
    }

    function refresh() {
        if (refreshProcess.running || root.disconnecting)
            return;
        root.refreshing = true;
        refreshProcess.running = true;
    }

    function openLogin() {
        const terminal = String(Config.options.apps?.terminal ?? "kitty -1").trim() || "kitty -1";
        const helper = root.shellQuote(root.helperPath);
        const inner = root.runtimePythonShell()
            + ` "$PY" ${helper} login; `
            + 'printf "\\nSign-in finished. Return to Vynx Settings and press Refresh now.\\n"; read _';
        Quickshell.execDetached(["sh", "-lc", `${terminal} sh -lc ${root.shellQuote(inner)}`]);
    }

    function disconnect() {
        if (disconnectProcess.running || refreshProcess.running)
            return;
        root.disconnecting = true;
        disconnectProcess.running = true;
    }

    function setPollingMinutes(value) {
        const minutes = Math.max(5, Math.min(180, Math.round(Number(value))));
        if (!Number.isFinite(minutes) || settingsProcess.running)
            return;
        root.pollingMinutes = minutes;
        root.savingPollingInterval = true;
        settingsProcess.command = [
            "sh",
            "-c",
            root.runtimePythonShell() + ' exec "$PY" "$1" set-interval "$2"',
            "vynx-apple-battery-settings",
            root.helperPath,
            String(minutes)
        ];
        settingsProcess.running = true;
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

        for (let i = 0; i < root.devices.length; ++i) {
            const device = root.devices[i];
            if (!device?.id || seen[device.id] || root.isExpired(device))
                continue;
            merged.push(device);
        }

        return merged;
    }

    onRefreshIntervalChanged: {
        if (refreshTimer.running)
            refreshTimer.restart();
    }

    Component.onCompleted: root.refresh()

    Timer {
        id: refreshTimer
        interval: root.state === "error" ? root.errorRetryInterval : root.refreshInterval
        repeat: true
        running: root.state === "connected" || root.state === "error"
        onTriggered: root.refresh()
    }

    Process {
        id: refreshProcess
        command: [
            "sh",
            "-c",
            root.runtimePythonShell() + ' exec "$PY" "$1" status',
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
                    if (payload.pollingMinutes !== undefined)
                        root.pollingMinutes = Math.max(5, Math.min(180, Number(payload.pollingMinutes)));
                    if (root.state === "connected") {
                        root.devices = root.mergeDevices(payload.devices);
                        root.lastRefresh = payload.observedAt ?? root.lastAttempt;
                    }
                } catch (error) {
                    root.state = "error";
                    console.warn(`[AppleBatteryStatus] Invalid helper response: ${error.message}`);
                }
            }
        }
    }

    Process {
        id: settingsProcess
        command: ["true"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.savingPollingInterval = false;
                if (!text.length)
                    return;
                try {
                    const payload = JSON.parse(text);
                    if (payload.pollingMinutes !== undefined)
                        root.pollingMinutes = Math.max(5, Math.min(180, Number(payload.pollingMinutes)));
                } catch (error) {
                    console.warn(`[AppleBatteryStatus] Invalid settings response: ${error.message}`);
                }
            }
        }
    }

    Process {
        id: disconnectProcess
        command: [
            "sh",
            "-c",
            root.runtimePythonShell() + ' exec "$PY" "$1" disconnect',
            "vynx-apple-battery-disconnect",
            root.helperPath
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.disconnecting = false;
                root.devices = [];
                root.lastRefresh = 0;
                root.lastAttempt = Date.now();
                root.state = "notConfigured";
            }
        }
    }
}
