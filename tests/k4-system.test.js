const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const base = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(base, name), "utf8");

test("system adapter reuses demand-driven ii-vynx resource services", () => {
    const source = read("K4System.qml");
    assert.match(source, /ResourceUsage\.registerOverlayResourceConsumer/);
    assert.match(source, /ResourceUsage\.unregisterOverlayResourceConsumer/);
    assert.match(source, /NetworkUsage\.activeInstances/);
    assert.match(source, /SystemInfo\.hostname/);
    assert.doesNotMatch(source, /Process\s*\{/);
});

test("system plugin preserves pinned k4 priority and geometry", () => {
    const source = read("K4SystemPlugin.qml");
    assert.match(source, /name:\s*"system"/);
    assert.match(source, /priority:\s*62/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /islandWidth:\s*700/);
    assert.match(source, /islandHeight:\s*430/);
    assert.match(source, /onOpenChanged/);
    assert.match(source, /target:\s*"k4\.system"/);
});

test("system utility is registered", () => {
    const source = read("K4BuiltinPlugins.qml");
    assert.match(source, /systemPlugin/);
    assert.match(source, /K4SystemPlugin\s*\{/);
});
