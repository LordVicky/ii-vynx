import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Scope {
    id: root

    property bool hyprGlassLoaded: false
    property bool hyprGlassInstalled: false
    property bool shellManagedPlugin: false
    property bool configApplied: false
    property bool ready: false
    property string status: "probing"
    property string errorMessage: ""

    property string hyprlandVersion: ""
    property string hyprlandCommit: ""
    property string hyprlandAbiSuffix: ""
    property string managedPluginPath: ""
    property bool checkingAfterLoad: false
    property bool reapplyPending: false
    property bool verticalBarDedicatedSurfaceReady: false
    readonly property bool surfaceReady: Config.options.appearance.surfaceStyle === "liquidGlass"
        && root.ready
        && root.hyprGlassLoaded
        && root.configApplied
    readonly property bool dedicatedBarSurfaceActive: (Config.options.bar.cornerStyle === 0 || Config.options.bar.cornerStyle === 1 || Config.options.bar.cornerStyle === 2)
    readonly property bool dedicatedVerticalBarSurfaceActive: Config.options.bar.vertical && root.verticalBarDedicatedSurfaceReady
    readonly property string horizontalBarNamespace: root.dedicatedBarSurfaceActive
        ? "quickshell:bar-glass"
        : "quickshell:bar"
    readonly property bool darkMode: Appearance.m3colors.darkmode
    readonly property string glassTheme: {
        if (LiquidGlassSettings.options.followSystemTheme)
            return root.darkMode ? "dark" : "light";

        const manualTheme = String(LiquidGlassSettings.options.theme ?? "light").toLowerCase();
        return manualTheme === "dark" ? "dark" : "light";
    }

    // The main Glass intensity control is a genuine compositor-side master for
    // the optical material. 100% resolves to HyprGlass v0.7.0's native values.
    // Edge thickness stays independent because it changes the slab geometry,
    // while refraction, dispersion, highlights and dome magnification scale.
    readonly property real blurStrength: root.clampGlassValue(LiquidGlassSettings.options.blurStrength, 0.0, 4.0, 2.0)
    readonly property real glassIntensity: root.clampGlassValue(LiquidGlassSettings.options.refractionStrength / 0.6, 0.0, 2.0, 1.0)
    readonly property real refractionStrength: root.clampGlassValue(0.6 * root.glassIntensity, 0.0, 1.0, 0.6)
    readonly property real chromaticAberrationBase: root.clampGlassValue(LiquidGlassSettings.options.chromaticAberration, 0.0, 1.0, 0.5)
    readonly property real fresnelStrengthBase: root.clampGlassValue(LiquidGlassSettings.options.fresnelStrength, 0.0, 1.0, 0.6)
    readonly property real specularStrengthBase: root.clampGlassValue(LiquidGlassSettings.options.specularStrength, 0.0, 1.0, 0.8)
    readonly property real edgeThickness: root.clampGlassValue(LiquidGlassSettings.options.edgeThickness, 0.0, 0.15, 0.06)
    readonly property real lensDistortionBase: root.clampGlassValue(LiquidGlassSettings.options.lensDistortion, 0.0, 1.0, 0.5)
    readonly property real chromaticAberration: root.clampGlassValue(root.chromaticAberrationBase * root.glassIntensity, 0.0, 1.0, 0.5)
    readonly property real fresnelStrength: root.clampGlassValue(root.fresnelStrengthBase * root.glassIntensity, 0.0, 1.0, 0.6)
    readonly property real specularStrength: root.clampGlassValue(root.specularStrengthBase * root.glassIntensity, 0.0, 1.0, 0.8)
    readonly property real lensDistortion: root.clampGlassValue(root.lensDistortionBase * root.glassIntensity, 0.0, 1.0, 0.5)
    readonly property real shellTint: root.clampGlassValue(LiquidGlassSettings.options.shellTint, 0.0, 1.0, 0.0)
    readonly property real surfaceBrightness: root.clampGlassValue(LiquidGlassSettings.options.brightness, -1.0, 1.0, 0.0)
    readonly property color barSurfaceColor: {
        const tint = root.shellTint;
        const theme = Appearance.colors.colLayer0Base;
        // HyprGlass uses layer alpha as its mask. The neutral bar mask is 0.5%
        // opaque; the layer cutoff below sits at its 50% coverage point so the
        // rounded anti-alias fringe does not turn into full glass fragments.
        let alpha = 0.005 + (0.18 - 0.005) * tint;
        let red = 0.5 + (theme.r - 0.5) * tint;
        let green = 0.5 + (theme.g - 0.5) * tint;
        let blue = 0.5 + (theme.b - 0.5) * tint;

        // Match desktop-widget brightness: a cheap black/white scrim over the
        // finished glass instead of reconfiguring the expensive blur effect.
        const scrimAlpha = Math.abs(root.surfaceBrightness) * 0.6;
        if (scrimAlpha > 0) {
            const scrim = root.surfaceBrightness < 0 ? 0 : 1;
            const outAlpha = scrimAlpha + alpha * (1 - scrimAlpha);
            red = (scrim * scrimAlpha + red * alpha * (1 - scrimAlpha)) / outAlpha;
            green = (scrim * scrimAlpha + green * alpha * (1 - scrimAlpha)) / outAlpha;
            blue = (scrim * scrimAlpha + blue * alpha * (1 - scrimAlpha)) / outAlpha;
            alpha = outAlpha;
        }

        return Qt.rgba(red, green, blue, alpha);
    }
    readonly property color surfaceColor: root.barSurfaceColor
    readonly property string rendererConfigSignature: [
        root.blurStrength,
        root.refractionStrength,
        root.chromaticAberration,
        root.fresnelStrength,
        root.specularStrength,
        root.edgeThickness,
        root.lensDistortion,
    ].join("|")

    function clampGlassValue(value, minimum, maximum, fallback) {
        const numericValue = Number(value);
        if (!isFinite(numericValue))
            return fallback;
        return Math.max(minimum, Math.min(maximum, numericValue));
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

    function probeHyprlandVersion() {
        if (versionProbe.running)
            return;

        root.status = "probing";
        versionProbe.running = true;
    }

    function probeBundledPlugin() {
        if (bundleProbe.running)
            return;

        if (!/^_aq_[0-9]+(\.[0-9]+)+(_[a-z]+_[0-9]+(\.[0-9]+)+)+$/.test(root.hyprlandAbiSuffix)) {
            root.finish("error", "Hyprland returned an invalid dependency ABI identifier.");
            return;
        }

        root.status = "probing";
        bundleProbe.command = [
            "sh",
            "-c",
            `plugin="$HOME/.local/lib/ii-vynx/hyprglass/${root.hyprlandAbiSuffix}/hyprglass.so"
            test -f "$plugin" || exit 66
            command -v ldd >/dev/null 2>&1 || exit 68
            deps="$(ldd "$plugin" 2>&1)" || { printf '%s\\n' "$deps" >&2; exit 67; }
            if printf '%s\\n' "$deps" | grep -q 'not found'; then
                printf '%s\\n' "$deps" | grep 'not found' >&2
                exit 67
            fi
            printf '%s\\n' "$plugin"`
        ];
        bundleProbe.running = true;
    }

    function loadManagedPlugin() {
        if (pluginLoad.running || root.managedPluginPath.length === 0)
            return;

        // Claim ownership before loading so teardown can roll back if the
        // runtime is destroyed between hyprctl load and the completion probe.
        root.shellManagedPlugin = true;
        root.status = "loading";
        pluginLoad.command = ["hyprctl", "plugin", "load", root.managedPluginPath];
        pluginLoad.running = true;
    }

    function buildGlassConfigCommand() {
        return `
set -eu
fragment="$HOME/.config/hypr/hyprland/shellOverrides/liquid-glass.lua"
mkdir -p "$(dirname "$fragment")"
cat > "$fragment" <<'VYNX_LIQUID_GLASS'
-- Generated by ii-vynx while Liquid Glass is active. Do not edit.
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled = false,
        manage_window_blur = false,
        default_theme = "${root.glassTheme}",
        default_preset = "vynx",
        layers = { enabled = true },
    })

    -- Pin HyprGlass's native blur defaults and expose blur strength to the
    -- shell control. Keep the plugin tint transparent so Shell tint remains
    -- the single explicit color source for the bar.
    hg.preset("vynx", {
        blur_strength = ${root.blurStrength},
        blur_iterations = 3,
        refraction_strength = ${root.refractionStrength},
        chromatic_aberration = ${root.chromaticAberration},
        fresnel_strength = ${root.fresnelStrength},
        specular_strength = ${root.specularStrength},
        edge_thickness = ${root.edgeThickness},
        lens_distortion = ${root.lensDistortion},
        tint_color = 0xffffff00,
    })

    -- HyprGlass owns native blur only on the active horizontal glass surface.
    -- Hug, Float and Plain keep that responsibility on dedicated visual layers,
    -- including while the bar is auto-hidden or revealed.
    _G.iiVynxLiquidGlassBarBlurOverride = hl.layer_rule({
        name = "ii-vynx-liquid-glass-bar-native-blur-off",
        match = { namespace = "${root.horizontalBarNamespace}" },
        blur = false,
        blur_popups = false,
        order = ${root.dedicatedBarSurfaceActive ? 1 : 0},
    })

    -- Dedicated horizontal surfaces remove unrelated widget/content alpha from
    -- the layer HyprGlass captures while keeping the same low-alpha mask contract.
    hg.layer("${root.horizontalBarNamespace}", { preset = "vynx", mask_threshold = 0.0025 })
${root.dedicatedVerticalBarSurfaceActive ? "" : '    hg.layer("quickshell:verticalBar", { preset = "vynx", mask_threshold = 0.05 })'}
    hg.layer("quickshell:popup", { preset = "vynx", mask_threshold = 0.05 })
    hg.layer("quickshell:sidebar-dashboard-glass", { preset = "vynx", mask_threshold = 0.0025 })
end
VYNX_LIQUID_GLASS
hyprctl reload
`;
    }

    function scheduleConfigApply() {
        if (!root.configApplied || !root.hyprGlassLoaded)
            return;
        configApplyDebounce.restart();
    }

    function applyConfig() {
        if (configApply.running) {
            root.reapplyPending = true;
            return;
        }

        root.reapplyPending = false;
        root.ready = false;
        root.status = "configuring";
        configApply.command = ["sh", "-c", root.buildGlassConfigCommand()];
        configApply.running = true;
    }

    function shutdown() {
        const managed = root.shellManagedPlugin;
        const pluginPath = root.managedPluginPath;
        root.shellManagedPlugin = false;
        root.configApplied = false;

        if (managed && pluginPath.length > 0) {
            Quickshell.execDetached([
                "sh",
                "-c",
                "hyprctl eval 'if _G.iiVynxLiquidGlassBarBlurOverride then _G.iiVynxLiquidGlassBarBlurOverride:set_enabled(false) end' >/dev/null 2>&1 || true; rm -f \"$HOME/.config/hypr/hyprland/shellOverrides/liquid-glass.lua\"; hyprctl plugin unload \"$1\" >/dev/null 2>&1 || true; hyprctl reload >/dev/null 2>&1",
                "vynx-liquid-glass",
                pluginPath
            ]);
            return;
        }

        Quickshell.execDetached([
            "sh",
            "-c",
            "hyprctl eval 'if _G.iiVynxLiquidGlassBarBlurOverride then _G.iiVynxLiquidGlassBarBlurOverride:set_enabled(false) end' >/dev/null 2>&1 || true; rm -f \"$HOME/.config/hypr/hyprland/shellOverrides/liquid-glass.lua\"; hyprctl reload >/dev/null 2>&1"
        ]);
    }

    Component.onCompleted: root.probeLoaded(false)
    Component.onDestruction: root.shutdown()

    onGlassThemeChanged: root.scheduleConfigApply()
    onHorizontalBarNamespaceChanged: root.scheduleConfigApply()
    onDedicatedVerticalBarSurfaceActiveChanged: root.scheduleConfigApply()
    onRendererConfigSignatureChanged: root.scheduleConfigApply()

    Timer {
        id: configApplyDebounce
        interval: 300
        repeat: false
        onTriggered: root.applyConfig()
    }

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
                root.hyprGlassInstalled = true;
                root.applyConfig();
                return;
            }

            if (root.checkingAfterLoad) {
                root.finish("error", "HyprGlass did not load after hyprctl plugin load.");
                return;
            }

            root.probeHyprlandVersion();
        }
    }

    Process {
        id: versionProbe
        running: false
        command: ["hyprctl", "-j", "version"]

        stdout: StdioCollector {
            id: versionOutput
        }
        stderr: StdioCollector {
            id: versionError
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.finish("error", versionError.text.trim() || "Could not query the Hyprland version.");
                return;
            }

            try {
                const version = JSON.parse(versionOutput.text);
                root.hyprlandVersion = String(version.version ?? "").trim();
                root.hyprlandCommit = String(version.commit ?? "").trim();
                const abiHash = String(version.abiHash ?? "").trim();
                const abiMarker = abiHash.indexOf("_aq_");
                root.hyprlandAbiSuffix = abiMarker >= 0 ? abiHash.slice(abiMarker) : "";
            } catch (error) {
                root.finish("error", "Could not parse the Hyprland version.");
                return;
            }

            root.probeBundledPlugin();
        }
    }

    Process {
        id: bundleProbe
        running: false
        command: ["true"]

        stdout: StdioCollector {
            id: bundleOutput
        }
        stderr: StdioCollector {
            id: bundleError
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 66) {
                root.finish("unavailable", `No bundled HyprGlass build for Hyprland ${root.hyprlandVersion} ABI ${root.hyprlandAbiSuffix}.`);
                return;
            }

            if (exitCode === 67) {
                root.finish("unavailable", bundleError.text.trim() || "Bundled HyprGlass has unresolved runtime dependencies.");
                return;
            }

            if (exitCode === 68) {
                root.finish("unavailable", "Could not validate bundled HyprGlass runtime dependencies because ldd is unavailable.");
                return;
            }

            if (exitCode !== 0) {
                root.finish("error", bundleError.text.trim() || "Could not resolve the bundled HyprGlass plugin.");
                return;
            }

            root.managedPluginPath = bundleOutput.text.trim();
            if (root.managedPluginPath.length === 0) {
                root.finish("error", "Bundled HyprGlass path was empty.");
                return;
            }

            root.hyprGlassInstalled = true;
            root.loadManagedPlugin();
        }
    }

    Process {
        id: pluginLoad
        running: false
        command: ["true"]

        stderr: StdioCollector {
            id: pluginLoadError
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.shellManagedPlugin = false;
                root.finish("error", pluginLoadError.text.trim() || "Could not load the bundled HyprGlass plugin.");
                return;
            }

            root.probeLoaded(true);
        }
    }

    Process {
        id: configApply
        running: false
        command: ["true"]

        stderr: StdioCollector {
            id: configApplyError
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.finish("error", configApplyError.text.trim() || "Could not configure HyprGlass.");
                return;
            }

            root.configApplied = true;
            root.finish(root.shellManagedPlugin ? "managed" : "user", "");

            if (root.reapplyPending) {
                root.reapplyPending = false;
                configApplyDebounce.restart();
            }
        }
    }
}
