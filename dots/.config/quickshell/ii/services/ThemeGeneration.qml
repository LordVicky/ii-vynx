pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property var pendingCommand: []
    property string pendingKey: ""
    property bool pendingPreemptible: false
    property var activeCommand: []
    property string activeKey: ""
    property bool activePreemptible: false
    property bool cancelRequested: false
    property int cancelledProcessGroup: 0

    readonly property bool busy: applyProcess.running || coalesceTimer.running || handoffTimer.running || root.pendingCommand.length > 0

    signal applyStarted(string key)
    signal applyFinished(string key)
    signal applyFailed(string key, int exitCode, string message)

    function queue(command, key, preemptible) {
        root.pendingCommand = command;
        root.pendingKey = key || "";
        root.pendingPreemptible = preemptible === true;

        if (applyProcess.running) {
            // Generated palettes run in their own process group. If the user picks
            // something newer while one is still generating, terminate the stale
            // group and keep only the newest pending request.
            if (root.activePreemptible && root.pendingKey !== root.activeKey)
                root.cancelActive();
            return;
        }

        coalesceTimer.restart();
    }

    function cancelActive() {
        if (!applyProcess.running || !root.activePreemptible || root.cancelRequested)
            return;

        const pid = Number(applyProcess.processId);
        if (!pid || pid <= 0)
            return;

        root.cancelRequested = true;
        root.cancelledProcessGroup = pid;
        Quickshell.execDetached(["kill", "-TERM", "--", `-${pid}`]);
        killEscalationTimer.restart();
    }

    function applyGenerated(type) {
        if (!type || type.length === 0)
            return;
        root.queue([
            "setsid",
            "bash",
            `${Directories.scriptPath}/colors/applycachedpalette.sh`,
            "--type",
            type
        ], type, true);
    }

    function applyGeneratedMode(type, mode) {
        if (!type || type.length === 0)
            return;
        if (mode !== "dark" && mode !== "light")
            return;
        root.queue([
            "setsid",
            "bash",
            `${Directories.scriptPath}/colors/applycachedpalette.sh`,
            "--type",
            type,
            "--mode",
            mode
        ], `${type}:${mode}`, true);
    }

    function applyFromConfig() {
        root.queue([
            "bash",
            `${Directories.scriptPath}/colors/applycachedpalette.sh`
        ], "config", false);
    }

    function applyThemeFile(path, type) {
        if (!path || path.length === 0)
            return;
        root.queue([
            "bash",
            `${Directories.scriptPath}/colors/publishpalette.sh`,
            "--source",
            path
        ], type || path, false);
    }

    function startPending() {
        if (applyProcess.running || root.pendingCommand.length === 0)
            return;

        root.activeCommand = root.pendingCommand;
        root.activeKey = root.pendingKey;
        root.activePreemptible = root.pendingPreemptible;
        root.pendingCommand = [];
        root.pendingKey = "";
        root.pendingPreemptible = false;

        applyProcess.command = root.activeCommand;
        root.applyStarted(root.activeKey);
        applyProcess.running = true;
    }

    function finish(exitCode, stderrText) {
        const finishedKey = root.activeKey;
        const wasCancelled = root.cancelRequested;

        root.activeCommand = [];
        root.activeKey = "";
        root.activePreemptible = false;
        root.cancelRequested = false;
        root.cancelledProcessGroup = 0;
        killEscalationTimer.stop();

        if (!wasCancelled) {
            if (exitCode === 0) {
                // Do not rely solely on filesystem watcher timing. Once the producer has
                // exited successfully, explicitly consume the final palette it published.
                MaterialThemeLoader.reapplyTheme();
                root.applyFinished(finishedKey);
            } else {
                const detail = (stderrText || "").trim();
                root.applyFailed(
                    finishedKey,
                    exitCode,
                    detail.length > 0 ? detail : `Theme generation failed with exit code ${exitCode}.`
                );
            }
        }

        if (root.pendingCommand.length > 0)
            handoffTimer.restart();
    }

    Timer {
        id: coalesceTimer
        interval: 30
        repeat: false
        onTriggered: root.startPending()
    }

    Timer {
        id: handoffTimer
        interval: 5
        repeat: false
        onTriggered: {
            if (applyProcess.running) {
                handoffTimer.restart();
                return;
            }
            root.startPending();
        }
    }

    Timer {
        id: killEscalationTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (!root.cancelRequested || !applyProcess.running || root.cancelledProcessGroup <= 0)
                return;
            Quickshell.execDetached([
                "kill",
                "-KILL",
                "--",
                `-${root.cancelledProcessGroup}`
            ]);
        }
    }

    Process {
        id: applyProcess
        stderr: StdioCollector { id: applyStderr }
        onExited: (exitCode, exitStatus) => root.finish(exitCode, applyStderr.text)
    }
}
