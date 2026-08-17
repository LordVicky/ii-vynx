pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property string presetDirectory: `${Directories.shellConfig}/presets`
    readonly property string scriptPath: `${Directories.scriptPath}/presets.sh`
    property alias model: presetsFolderModel
    property alias folderModel: presetsFolderModel
    readonly property bool busy: root.currentOperation.length > 0 || savePresetProc.running || applyPresetProc.running || removePresetProc.running
    property string currentOperation: ""
    property string errorMessage: ""

    signal operationFinished(string operation, string presetName)
    signal operationFailed(string operation, string presetName, string message)

    function refreshModel() {
        const current = presetsFolderModel.folder;
        presetsFolderModel.folder = "";
        presetsFolderModel.folder = current;
    }

    function begin(process, operation, presetName, command) {
        if (root.currentOperation.length > 0 || root.busy) {
            root.errorMessage = "Another preset operation is already running.";
            root.operationFailed(operation, presetName, root.errorMessage);
            return false;
        }

        root.errorMessage = "";
        root.currentOperation = operation;
        process.presetName = presetName;
        process.command = command;
        process.running = true;
        return root.currentOperation === operation;
    }

    function finish(operation, presetName, exitCode, stderrText, refresh) {
        root.currentOperation = "";
        if (exitCode === 0) {
            root.errorMessage = "";
            if (refresh)
                root.refreshModel();
            root.operationFinished(operation, presetName);
            return;
        }

        const detail = (stderrText || "").trim();
        root.errorMessage = detail.length > 0
            ? detail
            : `Preset ${operation} failed with exit code ${exitCode}.`;
        root.operationFailed(operation, presetName, root.errorMessage);
    }

    function handleStoppedWithoutExit(process, operation) {
        if (process.running || root.currentOperation !== operation)
            return;

        root.currentOperation = "";
        root.errorMessage = `Failed to start preset backend for ${operation}: ${root.scriptPath}`;
        root.operationFailed(operation, process.presetName, root.errorMessage);
    }

    function save(name, description, replace) {
        const presetName = name || "";
        if (presetName.length === 0) {
            root.errorMessage = "Preset name cannot be empty.";
            root.operationFailed("save", presetName, root.errorMessage);
            return false;
        }

        const command = [root.scriptPath, replace ? "--replace" : "--save", presetName];
        if (description && description.length > 0)
            command.push(description);
        return root.begin(savePresetProc, "save", presetName, command);
    }

    function apply(name) {
        return root.begin(applyPresetProc, "apply", name, [root.scriptPath, "--apply", name]);
    }

    function remove(name) {
        return root.begin(removePresetProc, "remove", name, [root.scriptPath, "--remove", name]);
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.presetDirectory])

    FolderListModel {
        id: presetsFolderModel
        folder: Qt.resolvedUrl(root.presetDirectory)
        nameFilters: ["*.json"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    Process {
        id: savePresetProc
        property string presetName: ""
        stderr: StdioCollector { id: savePresetStderr }
        onExited: (exitCode, exitStatus) => root.finish("save", presetName, exitCode, savePresetStderr.text, true)
        onRunningChanged: root.handleStoppedWithoutExit(savePresetProc, "save")
    }

    Process {
        id: applyPresetProc
        property string presetName: ""
        stderr: StdioCollector { id: applyPresetStderr }
        onExited: (exitCode, exitStatus) => root.finish("apply", presetName, exitCode, applyPresetStderr.text, false)
        onRunningChanged: root.handleStoppedWithoutExit(applyPresetProc, "apply")
    }

    Process {
        id: removePresetProc
        property string presetName: ""
        stderr: StdioCollector { id: removePresetStderr }
        onExited: (exitCode, exitStatus) => root.finish("remove", presetName, exitCode, removePresetStderr.text, true)
        onRunningChanged: root.handleStoppedWithoutExit(removePresetProc, "remove")
    }
}
