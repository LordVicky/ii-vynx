const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const k4 = (...parts) => path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar", ...parts);
const read = file => fs.readFileSync(file, "utf8");

test("clipboard adapter reuses ii-vynx Cliphist without a second watcher", () => {
    const source = read(k4("K4Clipboard.qml"));
    assert.match(source, /import qs\.services/);
    assert.match(source, /Cliphist\.fuzzyQuery/);
    assert.match(source, /Cliphist\.copy/);
    assert.match(source, /Cliphist\.deleteEntry/);
    assert.match(source, /Cliphist\.wipe/);
    assert.doesNotMatch(source, /wl-paste/);
    assert.doesNotMatch(source, /Process\s*\{/);
});

test("clipboard adapter exposes only the live K4 surface to shell routing", () => {
    const source = read(k4("K4Clipboard.qml"));
    assert.match(source, /property var plugin:\s*null/);
    assert.match(source, /function toggleSurface\(\)[\s\S]*?plugin\.toggle\(\)/);
    assert.match(source, /function closeSurface\(\)[\s\S]*?plugin\.close\(\)/);
});

test("clipboard plugin preserves upstream priority, geometry and keyboard contract", () => {
    const source = read(k4("K4ClipboardPlugin.qml"));
    assert.match(source, /name:\s*"clipboard"/);
    assert.match(source, /priority:\s*82/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /islandWidth:\s*720/);
    assert.match(source, /islandHeight:\s*470/);
    assert.match(source, /grabKeyboard:\s*open/);
    assert.match(source, /Component\.onCompleted:\s*K4Clipboard\.plugin = root/);
    assert.match(source, /target:\s*"k4\.clipboard"/);
});

test("clipboard view carries the daily-driver keyboard actions", () => {
    const source = read(k4("K4ClipboardView.qml"));
    assert.match(source, /Qt\.Key_PageDown/);
    assert.match(source, /Qt\.Key_Delete/);
    assert.match(source, /Qt\.ControlModifier/);
    assert.match(source, /root\.plugin\.choose\(\)/);
});

test("clipboard is registered in the built-in utility catalog", () => {
    const source = read(k4("K4BuiltinPlugins.qml"));
    assert.match(source, /clipboardPlugin/);
    assert.match(source, /K4ClipboardPlugin\s*\{/);
});
