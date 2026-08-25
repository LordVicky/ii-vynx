import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 plugin settings persist enablement across static and managed lifecycles", async () => {
    const config = await read("modules/common/Config.qml");
    const adapter = await read("modules/ii/k4bar/K4Settings.qml");
    const base = await read("modules/ii/k4bar/K4Plugin.qml");
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const manager = await read("modules/ii/k4bar/K4PluginManager.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const settingsPlugin = await read("modules/ii/k4bar/K4SettingsPlugin.qml");
    const settingsView = await read("modules/ii/k4bar/K4SettingsView.qml");
    const row = await read("modules/ii/k4bar/K4SettingsPluginRow.qml");
    const host = await read("modules/ii/k4bar/K4Bar.qml");

    assert.match(config, /property JsonObject k4: JsonObject \{[\s\S]*?property list<string> disabledPlugins:\s*\[\]/);
    assert.match(adapter, /readonly property var disabledPlugins:\s*Config\.options\.bar\.k4\.disabledPlugins/);
    assert.match(adapter, /function pluginEnabled\(name\)/);
    assert.match(adapter, /function setPluginEnabled\(name, wanted\)[\s\S]*?Config\.options\.bar\.k4\.disabledPlugins = next/);

    assert.match(base, /property bool configurable:\s*true/);
    assert.match(base, /property bool closeOnDisable:\s*true/);
    assert.match(base, /property string loadError:\s*""/);
    assert.match(base, /onEnabledChanged:[\s\S]*?if \(root\.closeOnDisable\)[\s\S]*?root\.close\(\)[\s\S]*?releasePlacement\(\)/);
    assert.doesNotMatch(base, /onEnabledChanged:[\s\S]*?active = false/);
    assert.match(builtins, /volumePlugin:[\s\S]*?closeOnDisable:\s*false[\s\S]*?clockPlugin:[\s\S]*?closeOnDisable:\s*false[\s\S]*?playerPlugin:[\s\S]*?closeOnDisable:\s*false/);

    assert.match(settingsPlugin, /configurable:\s*false/);
    assert.match(settingsPlugin, /property var controller:\s*null/);
    assert.match(controller, /function isProtectedPlugin\(candidate\)[\s\S]*?candidate\.name === "idle"[\s\S]*?candidate\.name === "settings"[\s\S]*?candidate\.name\.startsWith\("demo-"\)[\s\S]*?candidate\.configurable === false/);
    assert.match(controller, /function configurablePlugins\(\)[\s\S]*?pluginManager\.descriptors[\s\S]*?result\.push\(descriptor\)/);
    assert.match(controller, /function applyPluginEnabled\(candidate, wanted\)[\s\S]*?candidate\.enabled = target/);
    assert.match(controller, /function applyPersistedEnablement\(\)[\s\S]*?pluginManager\.owns\(candidate\.name\)[\s\S]*?K4Settings\.pluginEnabled\(candidate\.name\)/);
    assert.match(controller, /function setPluginEnabled\(name, wanted\)[\s\S]*?pluginManager\.descriptor\(name\)[\s\S]*?pluginManager\.setEnabled\(name, wanted\)[\s\S]*?K4Settings\.setPluginEnabled\(name, target\)/);
    assert.match(controller, /function retryPlugin\(name\)[\s\S]*?pluginManager\.retry\(name\)/);
    assert.match(controller, /const settings = plugin\("settings"\)[\s\S]*?settings\.controller = root/);

    assert.match(manager, /K4Settings\.setPluginEnabled\(slot\.name, target\)/);
    assert.match(manager, /slot\.instance = null[\s\S]*?obj\.destroy\(\)/);

    assert.match(settingsView, /root\.plugin\.controller\.configurablePlugins\(\)/);
    assert.match(settingsView, /K4SettingsPluginRow/);
    assert.match(row, /plugin\.loadError\.length > 0/);
    assert.match(row, /plugin\.enabled \? "Loaded" : "Disabled"/);
    assert.match(row, /root\.controller\.retryPlugin\(root\.plugin\.name\)/);
    assert.match(row, /root\.controller\.setPluginEnabled\(root\.plugin\.name, value\)/);

    assert.match(host, /Loader\.Error[\s\S]*?modelData\.loadError = "View failed to load"/);
    assert.match(host, /Loader\.Ready[\s\S]*?modelData\.loadError = ""/);
});
