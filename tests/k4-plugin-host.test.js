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
    assert.match(source, /property bool transient:\s*false/);
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
    assert.match(source, /onEnabledChanged:[\s\S]*?active = false[\s\S]*?releasePlacement\(\)/);
    assert.match(source, /Component\.onDestruction:\s*releasePlacement\(\)/);
});

test("plugin controller owns priority arbitration, transient preemption and monitor routing", () => {
    const source = readShell("modules/ii/k4bar/K4PluginController.qml");

    assert.match(source, /!candidate\.enabled \|\| !candidate\.active/);
    assert.match(source, /candidate\.priority > best\.priority/);
    assert.match(source, /!candidate\.transient \|\| !candidate\.active/);
    assert.match(source, /typeof candidate\.close === "function"[\s\S]*?candidate\.close\(\)/);

    assert.match(source, /IslandState\.requestedScreen\.length > 0[\s\S]*?previous\.length === 0 \|\| previous === "idle"/);
    assert.match(source, /IslandState\.activeScreen = IslandState\.takeRequestedScreen\(\)/);
    assert.match(source, /IslandState\.occupant = activePlugin\?\.name \?\? ""/);
    assert.match(source, /activePlugin\.islandHeight > K4Theme\.baseHeight/);
    assert.match(source, /onActivePluginChanged:\s*publishActivePlugin\(\)/);
    assert.match(source, /Component\.onCompleted:\s*publishActivePlugin\(\)/);

    assert.match(source, /screenName === IslandState\.activeScreen \? winner : idlePlugin/);
    assert.match(source, /interval:\s*240[\s\S]*?IslandState\.hovered = false/);
    assert.match(source, /pluginHoverExitTimer\.interval = winner\.hoverExitDelay/);
    assert.match(source, /winner\?\.closeOnHoverExit[\s\S]*?winner\.hoverTimedOut\(\)/);
});

test("host renders the winner on one monitor and keeps idle fallback elsewhere", () => {
    const source = readShell("modules/ii/k4bar/K4Bar.qml");

    assert.match(source, /name:\s*"idle"[\s\S]*?priority:\s*0[\s\S]*?active:\s*true/);
    assert.match(source, /name:\s*"demo-transient"[\s\S]*?priority:\s*59[\s\S]*?transient:\s*true/);
    assert.match(source, /name:\s*"demo-secondary"[\s\S]*?priority:\s*70/);
    assert.match(source, /name:\s*"demo-primary"[\s\S]*?priority:\s*80/);

    assert.match(source, /function openDemo\(plugin, screenName\)[\s\S]*?if \(screenName\)[\s\S]*?IslandState\.requestScreen\(screenName\)[\s\S]*?plugin\.open\(\)/);
    assert.doesNotMatch(source, /function openDemo\(plugin, screenName\)[\s\S]*?requestFocusedScreen/);
    assert.match(source, /controller\.visiblePluginFor\(panelWindow\.screen\.name\)/);
    assert.match(source, /showingIdle[\s\S]*?idleContent\.desiredBodyWidth[\s\S]*?pluginVisible\.islandWidth/);

    assert.match(source, /exclusiveZone:\s*K4Theme\.baseHeight/);
    assert.match(source, /mask:\s*Region \{ item: IslandState\.suppressed \? null : island \}/);
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

test("K4-03 exposes a narrow debug harness for live arbitration validation", () => {
    const source = readShell("modules/ii/k4bar/K4Bar.qml");

    assert.match(source, /target:\s*"k4barDebug"/);
    assert.match(source, /function openPrimary\(\): void/);
    assert.match(source, /function openPrimaryOn\(screen: string\): void/);
    assert.match(source, /function openSecondary\(\): void/);
    assert.match(source, /function openTransient\(\): void/);
    assert.match(source, /function disablePrimary\(\): void/);
    assert.match(source, /function hideIsland\(\): void/);
    assert.match(source, /function placePrimary\(fraction: real, durationMs: int\): void/);
    assert.match(source, /function gesture\(name: string, strength: real\): void/);
    assert.match(source, /function status\(\): string/);
});
