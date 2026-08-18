import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool hyprGlassLoaded: false
    property bool hyprGlassInstalled: false
    property bool hyprGlassWasEnabled: false
    property bool shellManagedPlugin: false
    property bool ready: false
    property string status: "probing"
    property string errorMessage: ""

    property bool checkingAfterLoad: false

    function stripAnsi(text) {
        return text.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "");
    }

    function finish(statusValue, errorValue) {
        root.status = statusValue;
        root.errorMessage = errorValue ?? "";
        root.ready = true;
    }

    function probeLoaded(afterLoad) {
        if (loadedProbe.running)
            return;

        root.ready = false;
        root.status = "probing";
        root.checkingAfterLoad = afterLoad ?? false;
        loadedProbe.running = true;
    }

    function probeHyprpm() {
        if (hyprpmProbe.running)
            return;

        root.status = "probing";
        hyprpmProbe.running = true;
    }

    function loadManagedPlugin() {
        if (hyprpmEnable.running || hyprpmReload.running)
            return;

        root.status = "loading";
        hyprpmEnable.running = true;
    }

    function reloadUserEnabledPlugin() {
        if (hyprpmReload.running)
            return;

        root.status = "loading";
        hyprpmReload.running = true;
    }

    function shutdown() {
        if (!root.shellManagedPlugin)
            return;

        root.shellManagedPlugin = false;
        Quickshell.execDetached([
            "sh",
            "-c",
            "hyprpm disable hyprglass >/dev/null 2>&1; hyprpm reload >/dev/null 2>&1"
        ]);
    }

    Component.onCompleted: root.probeLoaded(false)
    Component.onDestruction: root.shutdown()

    Process {
        id: loadedProbe
        running: false
        command: ["hyprctl", "-j", "plugin", "list"]

        stdout: StdioCollector {
            id: loadedOutput
        }
        stderr: StdioCollector {
            id: loadedError
        }

        onExited: (exitCode, exitStatus) => {
            let loaded = false;

            if (exitCode === 0) {
                try {
                    const plugins = JSON.parse(loadedOutput.text);
                    loaded = plugins.some(plugin => String(plugin.name).toLowerCase() === "hyprglass");
                } catch (error) {
                    root.finish("error", "Could not parse Hyprland plugin state.");
                    return;
                }
            } else {
                root.finish("error", loadedError.text.trim() || "Could not query Hyprland plugins.");
                return;
            }

            root.hyprGlassLoaded = loaded;

            if (loaded) {
                root.finish(root.shellManagedPlugin ? "managed" : "user", "");
                return;
            }

            if (root.checkingAfterLoad) {
                root.finish("error", "HyprGlass did not load after hyprpm reload.");
                return;
            }

            root.probeHyprpm();
        }
    }

    Process {
        id: hyprpmProbe
        running: false
        command: ["sh", "-c", "command -v hyprpm >/dev/null 2>&1 && hyprpm list"]

        stdout: StdioCollector {
            id: hyprpmOutput
        }
        stderr: StdioCollector {
            id: hyprpmError
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.finish("unavailable", hyprpmError.text.trim() || "hyprpm is not available.");
                return;
            }

            const clean = root.stripAnsi(hyprpmOutput.text);
            const lower = clean.toLowerCase();
            const marker = lower.indexOf("plugin hyprglass");

            if (marker === -1) {
                root.finish("unavailable", "HyprGlass is not installed through hyprpm.");
                return;
            }

            root.hyprGlassInstalled = true;

            const pluginBlock = clean.slice(marker, marker + 320);
            const enabledMatch = pluginBlock.match(/enabled:\s*(true|false)/i);
            if (!enabledMatch) {
                root.finish("error", "Could not determine HyprGlass hyprpm state.");
                return;
            }

            root.hyprGlassWasEnabled = enabledMatch[1].toLowerCase() === "true";

            if (root.hyprGlassWasEnabled)
                root.reloadUserEnabledPlugin();
            else
                root.loadManagedPlugin();
        }
    }

    Process {
        id: hyprpmEnable
        running: false
        command: ["hyprpm", "enable", "hyprglass"]

        stderr: StdioCollector {
            id: hyprpmEnableError
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.finish("error", hyprpmEnableError.text.trim() || "Could not enable HyprGlass.");
                return;
            }

            root.shellManagedPlugin = true;
            root.reloadUserEnabledPlugin();
        }
    }

    Process {
        id: hyprpmReload
        running: false
        command: ["hyprpm", "reload"]

        stderr: StdioCollector {
            id: hyprpmReloadError
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.finish("error", hyprpmReloadError.text.trim() || "Could not reload Hyprland plugins.");
                return;
            }

            root.probeLoaded(true);
        }
    }
}
