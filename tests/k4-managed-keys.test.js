const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("K4 Keys uses the accepted stable proxy lifecycle", () => {
    const builtins = readShell("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const plugin = readShell("modules/ii/k4bar/K4KeysPlugin.qml");

    assert.match(builtins, /property QtObject keysPlugin:\s*K4ManagedPlugin\s*\{/);
    assert.match(builtins, /name:\s*"keys"/);
    assert.match(builtins, /title:\s*"Shortcuts"/);
    assert.match(builtins, /application:\s*true/);
    assert.match(builtins, /applicationGlyph:\s*String\.fromCodePoint\(0xF030C\)/);
    assert.match(builtins, /source:\s*Qt\.resolvedUrl\("K4KeysPlugin\.qml"\)/);
    assert.doesNotMatch(builtins, /property QtObject keysPlugin:\s*K4KeysPlugin/);

    // The private implementation keeps the established utility behavior/IPC.
    assert.match(plugin, /priority:\s*65/);
    assert.match(plugin, /target:\s*"k4\.keys"/);
    assert.match(plugin, /function\s+openApplication\(\)/);

    // Registry ordering is unchanged so controller/app arbitration stays stable.
    assert.match(builtins, /systemPlugin,\s*sessionPlugin,\s*keysPlugin,\s*weatherPlugin/);
});
