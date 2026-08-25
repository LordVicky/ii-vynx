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

test("K4 lifecycle keeps metadata stable while the live instance changes", async () => {
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const settingsView = await read("modules/ii/k4bar/K4SettingsView.qml");
    const appsPlugin = await read("modules/ii/k4bar/K4AppsPlugin.qml");
    const settingsRow = await read("modules/ii/k4bar/K4SettingsPluginRow.qml");
    const host = await read("modules/ii/k4bar/K4Bar.qml");

    // Persistent metadata is copied into host-owned arrays once the controller
    // is initialized. UI models bind to those arrays directly; they do not call
    // helper functions whose dependency timing can omit a managed descriptor.
    assert.match(controller, /property var configurablePluginModel:\s*\[\]/);
    assert.match(controller, /property var applicationPluginModel:\s*\[\]/);
    assert.match(controller, /function rebuildMetadataModels\(\)/);
    assert.match(controller, /configurablePluginModel\s*=\s*configurable/);
    assert.match(controller, /applicationPluginModel\s*=\s*applications/);
    assert.match(controller, /Component\.onCompleted:[\s\S]*?rebuildMetadataModels\(\)/);
    assert.match(settingsView, /model:\s*root\.plugin\.controller\s*\?\s*root\.plugin\.controller\.configurablePluginModel\s*:\s*\[\]/);
    assert.doesNotMatch(settingsView, /configurablePlugins\(\)/);
    assert.match(appsPlugin, /controller\s*\?\s*controller\.applicationPluginModel\s*:\s*\[\]/);
    assert.doesNotMatch(appsPlugin, /controller\.applicationPlugins\(\)/);

    // Settings/Apps metadata must not be derived from the mutable live-plugin
    // array. Destroying a managed instance while a delegate handles the disable
    // click previously nulled modelData and could crash QtQmlModels.
    assert.match(controller, /function metadataPlugins\(\)/);
    assert.match(controller, /for \(let i = 0; i < seedPlugins\.length; \+\+i\)/);
    assert.match(controller, /for \(let i = 0; i < builtins\.plugins\.length; \+\+i\)/);
    assert.match(controller, /for \(let i = 0; i < pluginManager\.descriptors\.length; \+\+i\)/);
    assert.doesNotMatch(controller, /configurablePluginModel\s*=\s*plugins/);
    assert.doesNotMatch(controller, /applicationPluginModel\s*=\s*plugins/);

    // The island renderer only needs the current winner. Do not feed a mutable
    // QObject array into another Repeater during instance destruction.
    assert.doesNotMatch(host, /Repeater\s*\{\s*model:\s*controller\.plugins/);
    assert.match(host, /Loader\s*\{[\s\S]*?sourceComponent:\s*panelWindow\.pluginVisible\?\.view\s*\?\?\s*null/);

    // Teardown is allowed to null QObject references. Bindings and click
    // handlers must tolerate that rather than dereferencing a dying delegate.
    assert.match(settingsRow, /readonly property var safePlugin:\s*plugin\s*\?\?\s*null/);
    assert.match(settingsRow, /safePlugin\?\.loadError/);
    assert.match(settingsRow, /const candidate = root\.safePlugin/);
    assert.match(controller, /if \(!pluginManager\)/);
});

test("K4 lifecycle keeps metadata visible while the live instance is absent", async () => {
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const settingsRow = await read("modules/ii/k4bar/K4SettingsPluginRow.qml");

    assert.match(controller, /function configurablePlugins\(\)[\s\S]*?return configurablePluginModel/);
    assert.match(controller, /function applicationPlugins\(\)[\s\S]*?return applicationPluginModel/);
    assert.match(controller, /pluginManager\.owns\(/);
    assert.match(controller, /pluginManager\.descriptor\(/);
    assert.match(controller, /candidate\.application\s*===\s*true/);
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
