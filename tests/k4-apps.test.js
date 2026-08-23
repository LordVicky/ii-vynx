const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("k4 plugin contract carries explicit utility metadata", () => {
    const source = readShell("modules/ii/k4bar/K4Plugin.qml");

    assert.match(source, /property bool application:\s*false/);
    assert.match(source, /property string applicationGlyph:\s*""/);
    assert.match(source, /function openApplication\(\)[\s\S]*?if \(enabled\)[\s\S]*?active = true/);
});

test("k4 controller exposes applications from the existing plugin registry", () => {
    const source = readShell("modules/ii/k4bar/K4PluginController.qml");

    assert.match(source, /function applicationPlugins\(\)/);
    assert.match(source, /candidate\.name !== "apps" && candidate\.application === true/);
    assert.match(source, /result\.push\(candidate\)/);
    assert.match(source, /function openApplication\(name\)/);
    assert.match(source, /!target\.enabled \|\| target\.application !== true/);
    assert.match(source, /target\.openApplication\(\)/);
    assert.doesNotMatch(source, /property\s+var\s+applicationCatalog/);
});

test("k4 apps plugin preserves pinned utility-grid arbitration and geometry", () => {
    const source = readShell("modules/ii/k4bar/K4AppsPlugin.qml");

    assert.match(source, /name:\s*"apps"/);
    assert.match(source, /priority:\s*72/);
    assert.match(source, /active:\s*enabled && open/);
    assert.match(source, /viewLoaded:\s*open/);
    assert.match(source, /grabKeyboard:\s*open/);
    assert.match(source, /islandWidth:\s*700/);
    assert.match(source, /islandHeight:\s*520/);
    assert.match(source, /readonly property int columns:\s*5/);
    assert.match(source, /controller \? controller\.applicationPlugins\(\) : \[\]/);
    assert.match(source, /function launch\(id\)[\s\S]*?close\(\)[\s\S]*?controller\.openApplication\(id\)/);
    assert.match(source, /target:\s*"k4\.apps"/);
});

test("k4 apps view keeps the five-column searchable keyboard grid", () => {
    const source = readShell("modules/ii/k4bar/K4AppsView.qml");

    assert.match(source, /text:\s*"Search K4 utilities"/);
    assert.match(source, /model:\s*root\.plugin\.applications/);
    assert.match(source, /cellWidth:\s*width \/ root\.plugin\.columns/);
    assert.match(source, /Qt\.Key_Escape[\s\S]*?root\.plugin\.close\(\)/);
    assert.match(source, /Qt\.Key_Return \|\| event\.key === Qt\.Key_Enter[\s\S]*?root\.plugin\.launchSelected\(\)/);
    assert.match(source, /Qt\.Key_Right[\s\S]*?root\.plugin\.move\(1, 0\)/);
    assert.match(source, /Qt\.Key_Left[\s\S]*?root\.plugin\.move\(-1, 0\)/);
    assert.match(source, /Qt\.Key_Down[\s\S]*?root\.plugin\.move\(0, 1\)/);
    assert.match(source, /Qt\.Key_Up[\s\S]*?root\.plugin\.move\(0, -1\)/);
    assert.match(source, /border\.color:\s*K4Theme\.blue/);
    assert.match(source, /No K4 utilities registered yet/);
});

test("k4 builtins register and wire the apps owner", () => {
    const builtins = readShell("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const controller = readShell("modules/ii/k4bar/K4PluginController.qml");
    const shortcuts = readShell("modules/ii/k4bar/K4ShortcutStrip.qml");

    assert.match(builtins, /plugins:\s*\[[\s\S]*?appsPlugin/);
    assert.match(builtins, /property QtObject appsPlugin:\s*K4AppsPlugin \{\}/);
    assert.match(controller, /const apps = plugin\("apps"\)[\s\S]*?apps\.controller = root/);
    assert.match(shortcuts, /plugin\("apps"\)/);
    assert.match(shortcuts, /onActivated:\s*root\.launch\(appsTarget\)/);
});
