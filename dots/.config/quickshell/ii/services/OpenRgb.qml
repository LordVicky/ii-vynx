pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import "OpenRgbEffects.js" as OpenRgbEffects

Singleton {
    id: root

    property bool available: false
    property bool refreshing: false
    property bool applying: false
    property int deviceCount: -1
    property var profiles: []
    property var effects: []
    property bool effectAvailable: false
    property string effectService: ""
    property string effectMenuPath: ""
    property int stopEffectsMenuId: -1
    property string effectError: ""
    property string lastError: ""
    property int pendingRefreshParts: 0

    readonly property var config: Config.options?.background?.widgets?.openRgb
    readonly property string activeProfile: root.config?.activeProfile ?? ""
    readonly property string activeEffect: root.config?.activeEffect ?? ""
    readonly property string activeKind: root.config?.activeKind ?? ""
    readonly property string effectiveActiveKind: root.activeKind.length > 0
        ? root.activeKind
        : (root.activeEffect.length > 0 ? "effect" : (root.activeProfile.length > 0 ? "profile" : ""))
    readonly property bool lightsEnabled: root.config?.lightsEnabled ?? true
    readonly property string configuredProfileDirectory: (root.config?.profileDirectory ?? "").trim()
    readonly property string powerHelperPath: FileUtils.trimFileProtocol(`${Quickshell.shellPath("services/OpenRgbPower.py")}`)
    readonly property string powerSelection: root.effectiveActiveKind === "effect" ? root.activeEffect : root.profilePath(root.activeProfile)
    readonly property bool busy: root.refreshing || root.applying

    readonly property string statusText: {
        if (root.applying)
            return "Applying…";
        if (root.refreshing)
            return "Refreshing…";
        if (!root.available)
            return "OpenRGB not found";
        if (root.lastError.length > 0)
            return root.lastError;
        if (root.deviceCount < 0)
            return "Ready";
        if (root.deviceCount === 0)
            return "No devices detected";
        return root.deviceCount === 1 ? "1 device" : `${root.deviceCount} devices`;
    }

    function profileIndex(name) {
        for (let i = 0; i < root.profiles.length; i++) {
            if (root.profiles[i].name === name)
                return i;
        }
        return -1;
    }

    function profilePath(name) {
        const index = root.profileIndex(name);
        return index >= 0 ? root.profiles[index].path : "";
    }

    function effectIndex(name) {
        for (let i = 0; i < root.effects.length; i++) {
            if (root.effects[i].name === name)
                return i;
        }
        return -1;
    }

    function finishRefreshPart() {
        root.pendingRefreshParts = Math.max(0, root.pendingRefreshParts - 1);
        if (root.pendingRefreshParts === 0)
            root.refreshing = false;
    }

    function refresh() {
        if (root.refreshing || root.applying)
            return;
        root.refreshing = true;
        root.lastError = "";
        root.pendingRefreshParts = 3;
        availabilityProc.running = false;
        profileScanProc.running = false;
        effectScanProc.running = false;
        availabilityProc.running = true;
        profileScanProc.running = true;
        effectScanProc.running = true;
    }

    function selectFirstProfileIfNeeded() {
        if (!Config.ready || root.profiles.length === 0)
            return;
        if (root.profileIndex(root.activeProfile) >= 0)
            return;
        root.config.activeProfile = root.profiles[0].name;
    }

    function applyProfile(name) {
        if (!root.available || root.applying)
            return;
        const path = root.profilePath(name);
        if (path.length === 0) {
            root.lastError = "Profile not found";
            return;
        }
        root.lastError = "";
        root.applying = true;
        applyProfileProc.targetName = name;
        applyProfileProc.targetPath = path;
        applyProfileProc.running = false;
        applyProfileProc.running = true;
    }

    function applyEffect(name) {
        if (!root.available || !root.effectAvailable || root.applying)
            return;
        const index = root.effectIndex(name);
        if (index < 0) {
            root.lastError = "Effect not found";
            return;
        }
        root.lastError = "";
        root.applying = true;
        applyEffectProc.targetName = name;
        applyEffectProc.targetMenuId = root.effects[index].menuId;
        applyEffectProc.targetService = root.effectService;
        applyEffectProc.targetMenuPath = root.effectMenuPath;
        applyEffectProc.running = false;
        applyEffectProc.running = true;
    }

    function cycleProfile(delta) {
        if (root.profiles.length === 0 || root.applying)
            return;
        let index = root.profileIndex(root.activeProfile);
        if (index < 0)
            index = 0;
        else
            index = (index + delta + root.profiles.length) % root.profiles.length;
        root.applyProfile(root.profiles[index].name);
    }

    function setLightsEnabled(enabled) {
        if (!root.available || root.applying || enabled === root.lightsEnabled)
            return;
        root.lastError = "";
        if (!enabled) {
            if (root.effectiveActiveKind.length === 0 || root.powerSelection.length === 0) {
                root.lastError = "Apply a profile or effect first";
                return;
            }
            root.applying = true;
            lightsOffProc.running = false;
            lightsOffProc.running = true;
            return;
        }

        if (root.effectiveActiveKind === "effect") {
            if (root.effectIndex(root.activeEffect) < 0) {
                root.lastError = "Active effect not found";
                return;
            }
            root.applyEffect(root.activeEffect);
            return;
        }
        if (root.effectiveActiveKind === "profile") {
            if (root.profileIndex(root.activeProfile) < 0) {
                root.lastError = "Active profile not found";
                return;
            }
            root.applyProfile(root.activeProfile);
            return;
        }
        root.lastError = "Apply a profile or effect first";
    }

    function toggleLights() {
        root.setLightsEnabled(!root.lightsEnabled);
    }

    Component.onCompleted: {
        if (Config.ready)
            root.refresh();
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                root.refresh();
        }
    }

    Process {
        id: availabilityProc
        command: ["bash", "-c", "command -v openrgb >/dev/null 2>&1 || command -v OpenRGB >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0;
            if (!root.available) {
                root.deviceCount = -1;
                root.finishRefreshPart();
                return;
            }
            deviceListProc.running = false;
            deviceListProc.running = true;
        }
    }

    Process {
        id: profileScanProc
        command: [
            "bash",
            "-c",
            "custom=\"$1\"; if [[ \"$custom\" == file://* ]]; then custom=\"${custom#file://}\"; fi; if [[ \"$custom\" == '~/'* ]]; then custom=\"$HOME/${custom:2}\"; fi; if [ -n \"$custom\" ]; then dirs=(\"$custom\"); else dirs=(\"${XDG_CONFIG_HOME:-$HOME/.config}/OpenRGB\" \"$HOME/.config/OpenRGB\"); fi; for dir in \"${dirs[@]}\"; do [ -d \"$dir\" ] || continue; find \"$dir\" -maxdepth 1 -type f -iname '*.orp' -print; done | awk '!seen[$0]++' | sort -f",
            "ii-openrgb",
            root.configuredProfileDirectory
        ]
        stdout: StdioCollector {
            id: profileOutput
            onStreamFinished: {
                const lines = profileOutput.text.split("\n").map(line => line.trim()).filter(line => line.length > 0);
                root.profiles = lines.map(path => {
                    const filename = path.split("/").pop() ?? path;
                    return {
                        name: filename.replace(/\.orp$/i, ""),
                        path: path
                    };
                });
                root.selectFirstProfileIfNeeded();
                root.finishRefreshPart();
            }
        }
    }

    Process {
        id: deviceListProc
        command: ["bash", "-c", "bin=\"$(command -v openrgb || command -v OpenRGB)\" || exit 127; exec \"$bin\" --list-devices"]
        stdout: StdioCollector {
            id: deviceOutput
            onStreamFinished: {
                const matches = deviceOutput.text.match(/^\s*\d+\s*:/gm);
                root.deviceCount = matches ? matches.length : 0;
            }
        }
        stderr: StdioCollector {
            id: deviceError
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.deviceCount = -1;
                const detail = deviceError.text.trim();
                root.lastError = detail.length > 0 ? detail.split("\n").pop() : "Device scan failed";
            }
            root.finishRefreshPart();
        }
    }

    Process {
        id: effectScanProc
        command: [
            "bash",
            "-c",
            "for attempt in {1..12}; do items=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null) || { sleep 0.25; continue; }; while IFS= read -r item; do service=${item%%/*}; item_path=/${item#*/}; id=$(busctl --user get-property \"$service\" \"$item_path\" org.kde.StatusNotifierItem Id 2>/dev/null) || continue; [[ $id == *'\"openrgb\"'* ]] || continue; menu_value=$(busctl --user get-property \"$service\" \"$item_path\" org.kde.StatusNotifierItem Menu 2>/dev/null) || continue; menu_path=$(printf '%s\\n' \"$menu_value\" | awk -F'\"' '{print $2}'); printf '%s\\n%s\\n' \"$service\" \"$menu_path\"; exec busctl --user --json=short call \"$service\" \"$menu_path\" com.canonical.dbusmenu GetLayout -- iias 0 -1 2 label children-display; done < <(printf '%s\\n' \"$items\" | awk -F'\"' '{for (i=2; i<=NF; i+=2) print $i}'); sleep 0.25; done; exit 2"
        ]
        stdout: StdioCollector {
            id: effectOutput
            onStreamFinished: {
                const lines = effectOutput.text.split("\n");
                root.effectService = lines.shift()?.trim() ?? "";
                root.effectMenuPath = lines.shift()?.trim() ?? "";
                const menuLayout = lines.join("\n").trim();
                root.effects = OpenRgbEffects.parseMenuLayout(menuLayout);
                root.stopEffectsMenuId = OpenRgbEffects.parseStopMenuId(menuLayout);
                root.effectAvailable = root.effectService.length > 0 && root.effectMenuPath.length > 0 && root.effects.length > 0;
                root.effectError = root.effectAvailable ? "" : "Effects Plugin unavailable";
                root.finishRefreshPart();
            }
        }
    }

    Process {
        id: applyProfileProc
        property string targetName: ""
        property string targetPath: ""
        command: [
            "bash",
            "-c",
            "bin=\"$(command -v openrgb || command -v OpenRGB)\" || exit 127; exec \"$bin\" --profile \"$1\"",
            "ii-openrgb",
            applyProfileProc.targetPath
        ]
        stderr: StdioCollector {
            id: applyProfileError
        }
        onExited: (exitCode, exitStatus) => {
            root.applying = false;
            if (exitCode === 0) {
                root.config.activeProfile = applyProfileProc.targetName;
                root.config.activeKind = "profile";
                root.config.lightsEnabled = true;
                root.lastError = "";
            } else {
                const detail = applyProfileError.text.trim();
                root.lastError = detail.length > 0 ? detail.split("\n").pop() : "Profile failed";
            }
        }
    }

    Process {
        id: applyEffectProc
        property string targetName: ""
        property int targetMenuId: -1
        property string targetService: ""
        property string targetMenuPath: ""
        command: [
            "busctl",
            "--user",
            "call",
            applyEffectProc.targetService,
            applyEffectProc.targetMenuPath,
            "com.canonical.dbusmenu",
            "Event",
            "isvu",
            `${applyEffectProc.targetMenuId}`,
            "clicked",
            "v",
            "i",
            "0",
            "0"
        ]
        stderr: StdioCollector {
            id: applyEffectError
        }
        onExited: (exitCode, exitStatus) => {
            root.applying = false;
            if (exitCode === 0) {
                root.config.activeEffect = applyEffectProc.targetName;
                root.config.activeKind = "effect";
                root.config.lightsEnabled = true;
                root.lastError = "";
            } else {
                const detail = applyEffectError.text.trim();
                root.lastError = detail.length > 0 ? detail.split("\n").pop() : "Effect failed";
                root.refresh();
            }
        }
    }

    Process {
        id: lightsOffProc
        command: [
            "python3",
            root.powerHelperPath,
            "off",
            "--kind",
            root.effectiveActiveKind,
            "--selection",
            root.powerSelection,
            "--service",
            root.effectService,
            "--menu-path",
            root.effectMenuPath,
            "--stop-id",
            `${root.stopEffectsMenuId}`
        ]
        stderr: StdioCollector {
            id: lightsOffError
        }
        onExited: (exitCode, exitStatus) => {
            root.applying = false;
            if (exitCode === 0) {
                root.config.lightsEnabled = false;
                root.lastError = "";
            } else {
                const detail = lightsOffError.text.trim();
                root.lastError = detail.length > 0 ? detail.split("\n").pop() : "Lights-off command failed";
            }
        }
    }
}
