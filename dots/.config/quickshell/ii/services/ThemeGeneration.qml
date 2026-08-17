pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property var pendingCommand: []
    property string pendingKey: ""
    property var activeCommand: []
    property string activeKey: ""

    readonly property bool busy: applyProcess.running || coalesceTimer.running || root.pendingCommand.length > 0

    signal applyStarted(string key)
    signal applyFinished(string key)
    signal applyFailed(string key, int exitCode, string message)

    function queue(command, key) {
        root.pendingCommand = command;
        root.pendingKey = key || "";

        // Coalesce rapid selections before starting expensive wallpaper color generation.
        // If a generation is already active, keep replacing the pending request so only
        // the newest selection runs after it finishes.
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
            coalesceTimer.restart();
    }

    Timer {
        id: coalesceTimer
        interval: 80
        repeat: false
        onTriggered: root.startPending()
    }

    Process {
        id: applyProcess
        stderr: StdioCollector { id: applyStderr }
        onExited: (exitCode, exitStatus) => root.finish(exitCode, applyStderr.text)
    }
}
