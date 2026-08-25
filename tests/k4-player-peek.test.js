const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("K4 player track changes can temporarily claim a hidden island", () => {
    const config = read("modules/common/Config.qml");
    const settings = read("modules/ii/k4bar/K4Settings.qml");
    const view = read("modules/ii/k4bar/K4SettingsView.qml");
    const builtins = read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property bool playerPeekOnTrackChange:\s*true/);
    assert.match(settings, /readonly property bool playerPeekOnTrackChange:\s*Config\.options\.bar\.k4\.playerPeekOnTrackChange/);
    assert.match(settings, /function setPlayerPeekOnTrackChange\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.playerPeekOnTrackChange = Boolean\(wanted\)/);
    assert.match(view, /title:\s*"Peek Player on track change"[\s\S]*?checked:\s*K4Settings\.playerPeekOnTrackChange[\s\S]*?setPlayerPeekOnTrackChange\(value\)/);

    assert.match(builtins, /name:\s*"player"[\s\S]*?property bool trackPeekOpen:\s*false/);
    assert.match(builtins, /readonly property string trackKey:[\s\S]*?trackTitle[\s\S]*?trackArtist/);
    assert.match(builtins, /onTrackKeyChanged:\s*trackSettleTimer\.restart\(\)/);
    assert.match(builtins, /id:\s*trackSettleTimer[\s\S]*?interval:\s*350/);
    assert.match(builtins, /const previous = playerPluginObject\.previousTrackKey[\s\S]*?playerPluginObject\.previousTrackKey = playerPluginObject\.trackKey/);
    assert.match(builtins, /!K4Settings\.playerPeekOnTrackChange \|\| !playerPluginObject\.enabled/);
    assert.match(builtins, /playerPluginObject\.trackKey\.length === 0[\s\S]*?previous\.length === 0[\s\S]*?previous === playerPluginObject\.trackKey/);
    assert.match(builtins, /playerPluginObject\.trackPeekOpen = true[\s\S]*?trackPeekTimer\.restart\(\)/);
    assert.match(builtins, /id:\s*trackPeekTimer[\s\S]*?interval:\s*3200[\s\S]*?playerPluginObject\.trackPeekOpen = false/);
    assert.match(builtins, /active:\s*enabled[\s\S]*?trackPeekOpen/);
    assert.match(builtins, /function close\(\) \{ trackPeekOpen = false \}/);
});
