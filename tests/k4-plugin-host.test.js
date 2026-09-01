const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("island state preserves k4 routing, geometry and temporary ownership contracts", () => {
    const source = readShell("modules/ii/k4bar/IslandState.qml");

    assert.match(source, /property string activeScreen:\s*""/);
    assert.match(source, /property string requestedScreen:\s*""/);
    assert.match(source, /function takeRequestedScreen\(\)[\s\S]*?requestedScreen \|\| focusedScreen\(\)/);
    assert.match(source, /Config\.options\.bar\.k4\.position === "bottom" \? "abajo" : "arriba"/);
    assert.match(source, /property var rect:\s*\(\{ x: 0, y: 0, ancho: 0, alto: 0 \}\)/);
    assert.match(source, /function publishRect\(screenName, value, isPrimary\)/);

    assert.match(source, /property string placementOwner:\s*""/);
    assert.match(source, /property real requestedPlacement:\s*-1/);
    assert.match(source, /requestedPlacement >= 0 \? requestedPlacement : basePlacement/);
    assert.match(source, /function requestPlacement\(owner, fraction, durationMs\)/);
    assert.match(source, /function releasePlacement\(owner\)/);

    assert.match(source, /signal gesture\(string name, real strength\)/);
    assert.match(source, /now - lastGestureAt < 500/);
    assert.match(source, /Math\.max\(0\.2, Math\.min\(1,/);

    assert.match(source, /readonly property bool suppressed:\s*hidden \|\| systemDialogs > 0/);
    assert.match(source, /running:\s*root\.systemDialogs > 0/);
    assert.match(source, /function resetHostPublication\(\)[\s\S]*?hidden = false[\s\S]*?systemDialogs = 0[\s\S]*?releasePlacement\(""\)/);
});

test("base plugin contract separates enabled state from active island requests", () => {
    const source = readShell("modules/ii/k4bar/K4Plugin.qml");

    assert.match(source, /required property string name/);
    assert.match(source, /property bool enabled:\s*true/);
    assert.match(source, /property bool active:\s*false/);
    assert.match(source, /property int priority:\s*50/);
    assert.match(source, /property bool transitorio:\s*false/);
    assert.doesNotMatch(source, /property bool transient\b/);
    assert.match(source, /property int islandWidth:\s*300/);
    assert.match(source, /property int islandHeight:\s*60/);
    assert.match(source, /property Component view:\s*null/);
    assert.match(source, /property bool viewLoaded:\s*true/);

    assert.match(source, /property bool grabKeyboard:\s*false/);
    assert.match(source, /property bool optionalKeyboard:\s*false/);
    assert.match(source, /property bool keyboardOnHover:\s*false/);
    assert.match(source, /property bool handlesBackgroundTap:\s*false/);
    assert.match(source, /property bool closeOnHoverExit:\s*false/);
    assert.match(source, /property int hoverExitDelay:\s*700/);

    assert.match(source, /function open\(\)[\s\S]*?if \(enabled\)[\s\S]*?active = true/);
    assert.match(source, /function requestPlacement\(fraction, durationMs\)[\s\S]*?if \(enabled\)[\s\S]*?IslandState\.requestPlacement/);
    assert.match(source, /function requestGesture\(gestureName, strength\)[\s\S]*?if \(enabled\)[\s\S]*?IslandState\.requestGesture/);
    assert.match(source, /onEnabledChanged:[\s\S]*?if \(!enabled\)[\s\S]*?active = false[\s\S]*?releasePlacement\(\)/);
    assert.match(source, /Component\.onDestruction:\s*releasePlacement\(\)/);
});

test("built-in plugins use direct declarative ownership without the withdrawn managed lifecycle", () => {
    const plugin = readShell("modules/ii/k4bar/K4Plugin.qml");
    const builtins = readShell("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const settings = readShell("modules/ii/k4bar/K4Settings.qml");
    const controller = readShell("modules/ii/k4bar/K4PluginController.qml");
    const config = readShell("modules/common/Config.qml");
    const k4Root = path.join(shellRoot, "modules/ii/k4bar");

    for (const type of ["Files", "Windows", "System", "Session", "Keys", "Weather", "Displays"])
        assert.match(builtins, new RegExp(`property QtObject ${type.toLowerCase()}Plugin:\\s*K4${type}Plugin\\s*\\{\\}`));

    assert.equal(fs.existsSync(path.join(k4Root, "K4ManagedPlugin.qml")), false);
    assert.equal(fs.existsSync(path.join(k4Root, "K4PluginLifecycleProbe.qml")), false);
    assert.equal(fs.existsSync(path.join(k4Root, "K4PluginLifecycleProbeHost.qml")), false);

    assert.doesNotMatch(plugin, /\b(configurable|closeOnDisable|loadError|instantiated)\b/);
    assert.doesNotMatch(config, /\bdisabledPlugins\b/);
    assert.doesNotMatch(settings, /\b(disabledPlugins|pluginEnabled|setPluginEnabled)\b/);
    assert.doesNotMatch(controller, /\b(applyPersistedEnablement|setPluginEnabled|disabledPlugins)\b/);
    assert.doesNotMatch(builtins, /K4ManagedPlugin|pluginLifecycleDebug|managedPlugin\s*\(/);
});

test("plugin controller owns priority arbitration, transient preemption and monitor routing", () => {
    const source = readShell("modules/ii/k4bar/K4PluginController.qml");

    assert.match(source, /!candidate\.enabled \|\| !candidate\.active/);
    assert.match(source, /candidate\.priority > best\.priority/);
    assert.match(source, /!candidate\.transitorio \|\| !candidate\.active/);
    assert.match(source, /winner\.transitorio/);
    assert.match(source, /typeof candidate\.close === "function"[\s\S]*?candidate\.close\(\)/);

    assert.match(source, /IslandState\.requestedScreen\.length > 0[\s\S]*?previous\.length === 0 \|\| previous === "idle"/);
    assert.match(source, /IslandState\.activeScreen = IslandState\.takeRequestedScreen\(\)/);
    assert.match(source, /IslandState\.occupant = activePlugin\?\.name \?\? ""/);
    assert.match(source, /activePlugin\.islandHeight > K4Theme\.baseHeight/);
    assert.match(source, /onActivePluginChanged:\s*publishActivePlugin\(\)/);

    assert.match(source, /readonly property bool passiveHoverEffective:\s*K4Settings\.expandIdleOnHover[\s\S]*?&& passiveHoverAllowed/);
    assert.match(source, /property QtObject builtins:\s*K4BuiltinPlugins \{[\s\S]*?passiveHoverAllowed:\s*root\.passiveHoverEffective[\s\S]*?\}/);
    assert.match(source, /function attachBuiltins\(\)[\s\S]*?builtins\.plugins[\s\S]*?plugins = combined/);
    assert.match(source, /Component\.onCompleted:\s*\{[\s\S]*?attachBuiltins\(\)[\s\S]*?publishActivePlugin\(\)[\s\S]*?\}/);

    assert.match(source, /screenName === IslandState\.activeScreen \? winner : idlePlugin/);
    assert.match(source, /interval:\s*240[\s\S]*?IslandState\.hovered = false/);
    assert.match(source, /pluginHoverExitTimer\.interval = winner\.hoverExitDelay/);
    assert.match(source, /winner\?\.closeOnHoverExit[\s\S]*?winner\.hoverTimedOut\(\)/);
});

test("host seeds only idle, then renders controller winners per monitor", () => {
    const source = readShell("modules/ii/k4bar/K4Bar.qml");

    assert.match(source, /name:\s*"idle"[\s\S]*?priority:\s*0[\s\S]*?active:\s*true/);
    assert.match(source, /K4PluginController\s*\{[\s\S]*?plugins:\s*\[idlePlugin\]/);
    assert.doesNotMatch(source, /demo-(?:transient|secondary|primary)|K4DemoView/);

    assert.match(source, /controller\.visiblePluginFor\(panelWindow\.screen\.name\)/);
    assert.match(source, /showingIdle[\s\S]*?idleContent\.desiredBodyWidth[\s\S]*?pluginVisible\.islandWidth/);

    assert.match(source, /readonly property string effectiveSpaceMode:\s*K4Settings\.spaceMode === "fullscreen"/);
    assert.match(source, /exclusiveZone:\s*panelWindow\.effectiveSpaceMode === "reserve"[\s\S]*?\? K4Theme\.baseHeight \+ panelWindow\.shapeInset : 0/);
    assert.match(source, /mask:\s*Region\s*\{[\s\S]*?item:\s*IslandState\.suppressed \? null : island/);
    assert.match(source, /opacity:\s*IslandState\.suppressed \? 0 : 1/);
    assert.match(source, /WlrLayershell\.keyboardFocus:[\s\S]*?plugin\.grabKeyboard[\s\S]*?plugin\.keyboardOnHover[\s\S]*?plugin\.optionalKeyboard/);
    assert.match(source, /Keys\.onPressed:[\s\S]*?Qt\.Key_Escape[\s\S]*?plugin\.close\(\)/);

    assert.match(source, /ancho:\s*island\.width/);
    assert.match(source, /alto:\s*island\.height/);
    assert.match(source, /name === "sacudida"/);
    assert.match(source, /name === "empujon"/);
    assert.match(source, /name === "tiron"/);

    assert.match(source, /delegate:\s*Loader[\s\S]*?active: modelData\?\.name !== "idle"[\s\S]*?modelData === panelWindow\.pluginVisible[\s\S]*?modelData\.enabled[\s\S]*?modelData\.viewLoaded/);
});

test("production host does not ship the retired K4-03 debug harness", () => {
    const source = readShell("modules/ii/k4bar/K4Bar.qml");
    const k4Root = path.join(shellRoot, "modules/ii/k4bar");

    assert.doesNotMatch(source, /import Quickshell\.Io/);
    assert.doesNotMatch(source, /IpcHandler\s*\{|target:\s*"k4barDebug"/);
    assert.doesNotMatch(source, /function (?:openDemo|closeDemos)\(/);
    assert.doesNotMatch(source, /\bdemo(?:Primary|Secondary|Transient)\b/);
    assert.equal(fs.existsSync(path.join(k4Root, "K4DemoView.qml")), false);
});
