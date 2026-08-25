import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 manages Displays as an independently loadable built-in", async () => {
    const manager = await read("modules/ii/k4bar/K4PluginManager.qml");
    const slot = await read("modules/ii/k4bar/K4PluginSlot.qml");
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(slot, /required property string entry/);
    assert.match(slot, /property var instance:\s*null/);
    assert.match(slot, /property string loadError:\s*""/);

    assert.match(manager, /K4PluginSlot\s*\{/);
    assert.match(manager, /name:\s*"displays"/);
    assert.match(manager, /entry:\s*"K4DisplaysPlugin\.qml"/);
    assert.match(manager, /Qt\.createComponent\(/);
    assert.match(manager, /createObject\(root\)/);
    assert.match(manager, /comp\.errorString\(\)/);
    assert.match(manager, /obj\.destroy\(\)/);
    assert.match(manager, /K4Settings\.pluginEnabled/);
    assert.match(manager, /K4Settings\.setPluginEnabled/);
    assert.match(manager, /function retry\(name\)/);
    assert.match(manager, /h\.enabled\s*=\s*false/);

    assert.doesNotMatch(manager, /FolderListModel|plugins\.py|\.config\/k4\/plugins|plugin store|registry/i);
    assert.doesNotMatch(builtins, /property QtObject displaysPlugin/);
    assert.doesNotMatch(builtins, /capturePlugin,\s*displaysPlugin,\s*trayPlugin/);

    assert.match(controller, /K4PluginManager\s*\{/);
    assert.match(controller, /function rebuildPlugins\(\)/);
    assert.match(controller, /function retryPlugin\(name\)/);
    assert.match(controller, /pluginManager\.descriptors/);
    assert.match(controller, /function onInstancesChanged\(\)/);
});

test("K4 lifecycle keeps metadata visible while the live instance is absent", async () => {
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const settingsRow = await read("modules/ii/k4bar/K4SettingsPluginRow.qml");

    assert.match(controller, /function configurablePlugins\(\)/);
    assert.match(controller, /function applicationPlugins\(\)/);
    assert.match(controller, /pluginManager\.owns\(/);
    assert.match(controller, /pluginManager\.descriptor\(/);
    assert.match(controller, /descriptor\.application\s*===\s*true/);
    assert.match(settingsRow, /retryPlugin/);
    assert.match(settingsRow, /click to retry/);
});

test("K4 lifecycle exposes a bounded failure-isolation debug seam", async () => {
    const manager = await read("modules/ii/k4bar/K4PluginManager.qml");

    assert.match(manager, /target:\s*"k4\.pluginLifecycleDebug"/);
    assert.match(manager, /function fail\(id: string\)/);
    assert.match(manager, /function restore\(id: string\)/);
    assert.match(manager, /function status\(\): string/);
});
