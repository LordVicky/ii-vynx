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
    property var activeCommand: []
    property string activeKey: ""

    readonly property bool busy: applyProcess.running || coalesceTimer.running || handoffTimer.running || root.pendingCommand.length > 0

    signal applyStarted(string key)
    signal applyFinished(string key)
    signal applyFailed(string key, int exitCode, string message)

    function queue(command, key) {
        root.pendingCommand = command;
        root.pendingKey = key || "";

        // Coalesce only the initial burst. While generation is active, keep replacing
        // the one pending request so the newest selection is handed off immediately.
        if (!applyProcess.running)
            coalesceTimer.restart();
    }

    function applyGenerated(type) {
        if (!type || type.length === 0)
            return;
        root.queue([Directories.wallpaperSwitchScriptPath, "--noswitch", "--type", type], type);
    }

    function applyFromConfig() {
        root.queue([Directories.wallpaperSwitchScriptPath, "--noswitch"], "config");
    }

    function applyThemeFile(path, type) {
        if (!path || path.length === 0)
            return;
        root.queue(["cp", "--", path, Directories.generatedMaterialThemePath], type || path);
    }

    function startPending() {
        if (applyProcess.running || root.pendingCommand.length === 0)
            return;

        root.activeCommand = root.pendingCommand;
        root.activeKey = root.pendingKey;
        root.pendingCommand = [];
        root.pendingKey = "";

        applyProcess.command = root.activeCommand;
        root.applyStarted(root.activeKey);
        applyProcess.running = true;
    }

    function finish(exitCode, stderrText) {
        const finishedKey = root.activeKey;
        root.activeCommand = [];
        root.activeKey = "";

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

    Process {
        id: applyProcess
        stderr: StdioCollector { id: applyStderr }
        onExited: (exitCode, exitStatus) => root.finish(exitCode, applyStderr.text)
    }
}
