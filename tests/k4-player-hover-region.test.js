const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(shellRoot, name), "utf8")
    .replace(/^\s*\/\/.*$/gm, "");

test("player hover is armed only from the scaled idle media region and clears on island exit", () => {
    const idle = read("K4IdlePill.qml");
    const state = read("IslandState.qml");
    const builtins = read("K4BuiltinPlugins.qml");

    assert.match(idle, /readonly property real mediaHoverWidth:[\s\S]*?Math\.min\(root\.width,[\s\S]*?leftMedia\.implicitWidth/);
    assert.match(idle, /Item\s*\{[\s\S]*?id:\s*mediaHoverZone[\s\S]*?width:\s*root\.mediaHoverWidth[\s\S]*?HoverHandler\s*\{\s*id:\s*mediaHover[\s\S]*?enabled:\s*root\.isPlaying/);
    assert.match(idle, /readonly property bool mediaHovered:\s*mediaHover\.hovered\s*&&\s*root\.isPlaying/);
    assert.match(idle, /onMediaHoveredChanged:\s*IslandState\.mediaHovered\s*=\s*root\.mediaHovered/);

    assert.match(state, /property bool mediaHovered:\s*false/);
    assert.match(state, /function resetHostPublication\(\)[\s\S]*?mediaHovered\s*=\s*false/);

    assert.match(builtins, /property bool clockHoverReady:\s*false/);
    assert.match(builtins, /Timer\s*\{[\s\S]*?id:\s*clockHoverIntent[\s\S]*?interval:\s*140/);
    assert.match(builtins, /function onMediaHoveredChanged\(\)[\s\S]*?clockHoverIntent\.stop\(\)[\s\S]*?root\.clockHoverReady\s*=\s*false[\s\S]*?root\.playerHoverSession\s*=\s*true/);
    assert.match(builtins, /active:\s*enabled\s*&&\s*IslandState\.hovered\s*&&\s*root\.passiveHoverAllowed\s*&&\s*root\.clockHoverReady\s*&&\s*!root\.playerHoverSession/);
    assert.match(builtins, /active:\s*enabled\s*&&\s*\([\s\S]*?IslandState\.hovered\s*&&\s*K4Media\.hasPlayer\s*&&\s*root\.playerHoverSession/);
    assert.doesNotMatch(builtins, /IslandState\.hovered\s*&&\s*root\.passiveHoverAllowed[\s\S]{0,100}?root\.playerHoverSession/);
    assert.match(builtins, /function onHoveredChanged\(\)[\s\S]*?if \(!IslandState\.hovered\)[\s\S]*?root\.playerHoverSession\s*=\s*false/);
});
