import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("idle hover expansion is a persisted K4 preference enabled by default", async () => {
    const config = await read("modules/common/Config.qml");
    const settings = await read("modules/ii/k4bar/K4Settings.qml");
    const view = await read("modules/ii/k4bar/K4SettingsView.qml");

    assert.match(config, /property JsonObject k4: JsonObject \{[\s\S]*?property bool expandIdleOnHover:\s*true/);
    assert.match(settings, /readonly property bool expandIdleOnHover:\s*Config\.options\.bar\.k4\.expandIdleOnHover/);
    assert.match(settings, /function setExpandIdleOnHover\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.expandIdleOnHover = Boolean\(wanted\)/);
    assert.match(view, /title:\s*"Expand idle pill on hover"[\s\S]*?checked:\s*K4Settings\.expandIdleOnHover[\s\S]*?K4Settings\.setExpandIdleOnHover\(value\)/);
});

test("idle hover preference gates only passive Clock and Player expansion", async () => {
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(controller, /readonly property bool passiveHoverEffective:\s*K4Settings\.expandIdleOnHover[\s\S]*?&& passiveHoverAllowed/);
    assert.match(controller, /K4BuiltinPlugins \{[\s\S]*?passiveHoverAllowed:\s*root\.passiveHoverEffective/);
    assert.match(controller, /function hoverEntered\(screenName\)[\s\S]*?IslandState\.hovered = true/);

    assert.match(builtins, /name:\s*"clock"[\s\S]*?active:\s*enabled && IslandState\.hovered && root\.passiveHoverAllowed/);
    assert.match(builtins, /name:\s*"player"[\s\S]*?IslandState\.hovered && root\.passiveHoverAllowed[\s\S]*?\|\| trackPeekOpen/);
    assert.match(builtins, /name:\s*"volume"[\s\S]*?active:\s*enabled && K4Audio\.overlayOpen/);
    assert.match(builtins, /name:\s*"toast"[\s\S]*?active:\s*enabled && K4Notifications\.toastOpen/);
});
