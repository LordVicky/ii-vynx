import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 Settings is an in-island application backed by existing bar config", async () => {
    const adapter = await read("modules/ii/k4bar/K4Settings.qml");
    const plugin = await read("modules/ii/k4bar/K4SettingsPlugin.qml");
    const view = await read("modules/ii/k4bar/K4SettingsView.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(adapter, /Config\.options\.bar\.k4\.position/);
    assert.match(adapter, /Config\.options\.bar\.k4\.alignment/);
    assert.match(adapter, /function setPosition\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.position = value/);
    assert.match(adapter, /function setAlignment\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.alignment = value/);
    assert.doesNotMatch(adapter, /FileView|\.local\/state|JsonAdapter/);

    assert.match(plugin, /name:\s*"settings"/);
    assert.match(plugin, /priority:\s*66/);
    assert.match(plugin, /application:\s*true/);
    assert.match(plugin, /active:\s*enabled\s*&&\s*open/);
    assert.match(plugin, /islandWidth:\s*600/);
    assert.match(plugin, /islandHeight:\s*640/);
    assert.match(plugin, /grabKeyboard:\s*open/);
    assert.match(plugin, /closeOnHoverExit:\s*true/);
    assert.match(plugin, /hoverExitDelay:\s*1200/);
    assert.match(plugin, /function openApplication\(\)[\s\S]*?openSettings\(\)/);
    assert.match(plugin, /K4Panel\.close\(\)/);
    assert.match(plugin, /target:\s*"k4\.settings"/);

    assert.match(view, /K4Settings\.positions/);
    assert.match(view, /K4Settings\.setPosition\(/);
    assert.match(view, /K4Settings\.alignments/);
    assert.match(view, /K4Settings\.setAlignment\(/);
    assert.doesNotMatch(view, /captura|editor|juego|plugin store/i);

    assert.match(builtins, /appsPlugin, settingsPlugin, launcherPlugin/);
    assert.match(builtins, /property QtObject settingsPlugin:\s*K4SettingsPlugin\s*\{\}/);
});
