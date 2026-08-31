const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("K4 exposes the active island screen through existing host state", () => {
    const state = read("modules/ii/k4bar/IslandState.qml");
    const controller = read("modules/ii/k4bar/K4PluginController.qml");

    assert.match(state, /property string activeScreen:\s*""/);
    assert.match(state, /property string requestedScreen:\s*""/);
    assert.match(state, /function requestScreen\(name\)[\s\S]*?requestedScreen = String\(name\)/);
    assert.match(state, /function takeRequestedScreen\(\)[\s\S]*?requestedScreen \|\| focusedScreen\(\)[\s\S]*?requestedScreen = ""[\s\S]*?return chosen/);

    assert.match(controller, /function publishActivePlugin\(\)[\s\S]*?IslandState\.activeScreen = IslandState\.takeRequestedScreen\(\)/);
    assert.match(controller, /function visiblePluginFor\(screenName\)[\s\S]*?screenName === IslandState\.activeScreen \? winner : idlePlugin/);

    assert.doesNotMatch(state, /hyprctl/);
    assert.doesNotMatch(controller, /hyprctl|Process\s*\{/);
});
