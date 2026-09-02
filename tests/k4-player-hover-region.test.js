const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(shellRoot, name), "utf8")
    .replace(/^\s*\/\/.*$/gm, "");

test("player hover is armed only from the idle media widget and clears on island exit", () => {
    const idle = read("K4IdlePill.qml");
    const state = read("IslandState.qml");
    const builtins = read("K4BuiltinPlugins.qml");

    assert.match(idle, /readonly property bool mediaHovered:\s*mediaHover\.hovered\s*&&\s*root\.isPlaying/);
    assert.match(idle, /RowLayout\s*\{[\s\S]*?id:\s*leftMedia[\s\S]*?HoverHandler\s*\{\s*id:\s*mediaHover[\s\S]*?enabled:\s*root\.isPlaying/);
    assert.match(idle, /onMediaHoveredChanged:\s*IslandState\.mediaHovered\s*=\s*root\.mediaHovered/);

    assert.match(state, /property bool mediaHovered:\s*false/);
    assert.match(state, /function resetHostPublication\(\)[\s\S]*?mediaHovered\s*=\s*false/);

    assert.match(builtins, /function onMediaHoveredChanged\(\)[\s\S]*?IslandState\.mediaHovered[\s\S]*?root\.playerHoverSession\s*=\s*true/);
    assert.match(builtins, /function onHoveredChanged\(\)[\s\S]*?if \(!IslandState\.hovered\) root\.playerHoverSession = false/);
    assert.doesNotMatch(builtins, /else if \(K4Media\.isPlaying\) root\.playerHoverSession = true/);
    assert.doesNotMatch(builtins, /onIsPlayingChanged\(\) \{ if \(IslandState\.hovered && K4Media\.isPlaying\) root\.playerHoverSession = true \}/);
});
