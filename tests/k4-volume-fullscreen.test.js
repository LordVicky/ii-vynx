const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("K4 volume HUD is promoted above fullscreen clients", () => {
    const bar = read("modules/ii/k4bar/K4Bar.qml");
    const builtins = read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(builtins, /name:\s*"volume"[\s\S]*?active:\s*enabled && K4Audio\.overlayOpen/);
    assert.match(bar, /readonly property bool notificationOverlay:[\s\S]*?pluginVisible\?\.name === "volume"/);
    assert.match(bar, /WlrLayershell\.layer:\s*notificationOverlay \? WlrLayer\.Overlay : WlrLayer\.Top/);
});
