const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const base = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(base, name), "utf8");

test("files adapter is on-demand and does not add a background index owner", () => {
    const source = read("K4Files.qml");
    assert.match(source, /interval:\s*160/);
    assert.match(source, /python3/);
    assert.match(source, /k4-file-search\.py/);
    assert.match(source, /Quickshell\.shellRoot/);
    assert.doesNotMatch(source, /Quickshell\.shellPath/);
    assert.doesNotMatch(source, /running:\s*true/);
    assert.doesNotMatch(source, /plocate|updatedb/);
});

test("files plugin preserves upstream utility contract", () => {
    const source = read("K4FilesPlugin.qml");
    assert.match(source, /name:\s*"files"/);
    assert.match(source, /priority:\s*81/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /islandWidth:\s*760/);
    assert.match(source, /islandHeight:\s*470/);
    assert.match(source, /target:\s*"k4\.files"/);
});

test("files view imports Quickshell and exposes keyboard open, reveal and copy actions", () => {
    const source = read("K4FilesView.qml");
    assert.match(source, /^import Quickshell$/m);
    assert.match(source, /Quickshell\.env\("HOME"\)/);
    assert.match(source, /Qt\.Key_Return/);
    assert.match(source, /Qt\.ControlModifier/);
    assert.match(source, /root\.plugin\.openContaining\(\)/);
    assert.match(source, /root\.plugin\.copyPath\(\)/);
});

test("file-search results always expose the containing directory", () => {
    const source = read("tools/k4-file-search.py");
    assert.match(source, /"directory":\s*os\.path\.dirname\(path\)/);
    assert.doesNotMatch(source, /"directory":\s*path if is_dir/);
});

test("files is registered as a built-in K4 utility", () => {
    const source = read("K4BuiltinPlugins.qml");
    assert.match(source, /filesPlugin/);
    assert.match(source, /K4FilesPlugin\s*\{/);
});
