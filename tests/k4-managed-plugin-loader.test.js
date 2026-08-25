const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("K4 managed plugins keep a stable proxy while Loader owns the implementation", () => {
    const base = readShell("modules/ii/k4bar/K4Plugin.qml");
    const managed = readShell("modules/ii/k4bar/K4ManagedPlugin.qml");
    const builtins = readShell("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const controller = readShell("modules/ii/k4bar/K4PluginController.qml");

    assert.match(base, /property bool instantiated:\s*true/);

    assert.match(managed, /K4Plugin\s*\{/);
    assert.match(managed, /required property url source/);
    assert.match(managed, /property var implementationLoader:\s*Loader\s*\{/);
    assert.match(managed, /active:\s*root\.enabled/);
    assert.match(managed, /source:\s*root\.source/);
    assert.match(managed, /asynchronous:\s*false/);
    assert.match(managed, /readonly property var instance:\s*implementationLoader\.item/);
    assert.match(managed, /instantiated:\s*instance !== null/);
    assert.match(managed, /active:\s*enabled && instance \? Boolean\(instance\.active\) : false/);
    assert.match(managed, /view:\s*instance \? instance\.view : null/);
    assert.match(managed, /function openApplication\(\)[\s\S]*?instance\.openApplication\(\)/);
    assert.match(managed, /function close\(\)[\s\S]*?instance\.close\(\)/);
    assert.doesNotMatch(managed, /Qt\.createComponent|createObject\s*\(|\.destroy\s*\(/);

    assert.match(builtins, /property QtObject displaysPlugin:\s*K4ManagedPlugin\s*\{/);
    assert.match(builtins, /name:\s*"displays"/);
    assert.match(builtins, /title:\s*"Displays"/);
    assert.match(builtins, /application:\s*true/);
    assert.match(builtins, /source:\s*Qt\.resolvedUrl\("K4DisplaysPlugin\.qml"\)/);
    assert.doesNotMatch(builtins, /property QtObject displaysPlugin:\s*K4DisplaysPlugin/);

    // The tracer must not reintroduce the failed manager/descriptor model.
    assert.doesNotMatch(controller, /K4PluginManager|pluginManager|seedPlugins|rebuildPlugins|metadataPlugins/);
});

test("K4 settings status is based on the stable proxy lifecycle", () => {
    const row = readShell("modules/ii/k4bar/K4SettingsPluginRow.qml");

    assert.match(row, /plugin\.instantiated/);
    assert.match(row, /"Loading"/);
    assert.match(row, /"Disabled"/);
    assert.match(row, /"Loaded"/);
    assert.match(row, /plugin\.loadError\.length > 0/);
});
