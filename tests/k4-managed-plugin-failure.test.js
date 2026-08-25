const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("K4 managed plugin load failures stay behind the stable proxy and can retry", () => {
    const managed = readShell("modules/ii/k4bar/K4ManagedPlugin.qml");
    const builtins = readShell("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const row = readShell("modules/ii/k4bar/K4SettingsPluginRow.qml");
    const controller = readShell("modules/ii/k4bar/K4PluginController.qml");

    assert.match(managed, /property bool retryGate:\s*true/);
    assert.match(managed, /property bool debugLoadFailure:\s*false/);
    assert.match(managed, /readonly property url effectiveSource:/);
    assert.match(managed, /active:\s*root\.enabled && root\.requestedEnabled && root\.retryGate/);
    assert.match(managed, /source:\s*root\.effectiveSource/);
    assert.match(managed, /Loader\.Error[\s\S]*?root\.loadError = "Component failed to load"/);
    assert.match(managed, /function scheduleLoad\(\)[\s\S]*?Qt\.callLater[\s\S]*?root\.retryGate = true/);
    assert.match(managed, /function retryLoad\(\)[\s\S]*?retryGate = false[\s\S]*?scheduleLoad\(\)/);
    assert.match(managed, /function debugFailLoad\(\)/);
    assert.match(managed, /function debugRestoreLoad\(\)/);
    assert.doesNotMatch(managed, /Qt\.createComponent|createObject\s*\(|\.destroy\s*\(/);

    assert.match(row, /function retryLoad\(\)[\s\S]*?plugin\.retryLoad\(\)/);
    assert.match(row, /text:\s*"Retry"/);
    assert.match(row, /enabled:\s*!root\.failed/);
    assert.match(row, /TapHandler\s*\{[\s\S]*?enabled:\s*root\.failed[\s\S]*?root\.toggleEnabled\(\)/);

    assert.match(builtins, /target:\s*"k4\.pluginLifecycleDebug"/);
    assert.match(builtins, /function fail\(name: string\)/);
    assert.match(builtins, /function restore\(name: string\)/);
    assert.match(builtins, /function retry\(name: string\)/);
    assert.match(builtins, /function status\(name: string\): string/);

    // Load failure/retry must not revive the failed mutable-registry manager.
    assert.doesNotMatch(controller, /K4PluginManager|pluginManager|rebuildPlugins|metadataPlugins/);
});
