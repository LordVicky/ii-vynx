const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const base = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(base, name), "utf8");

test("windows adapter reuses ii-vynx HyprlandData", () => {
    const source = read("K4Windows.qml");
    assert.match(source, /import qs\.services/);
    assert.match(source, /HyprlandData\.windowList/);
    assert.match(source, /HyprlandData\.updateWindowList/);
    assert.doesNotMatch(source, /hyprctl",\s*"clients/);
});

test("windows plugin keeps pinned k4 priority and dynamic geometry", () => {
    const source = read("K4WindowsPlugin.qml");
    assert.match(source, /name:\s*"windows"/);
    assert.match(source, /priority:\s*83/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /Math\.min\(880,\s*Math\.max\(360,\s*60 \+ count \* 128\)\)/);
    assert.match(source, /islandHeight:\s*190/);
    assert.match(source, /target:\s*"k4\.windows"/);
});

test("windows view supports alt-tab style cycling and dwell activation", () => {
    const source = read("K4WindowsView.qml");
    assert.match(source, /dwellDelay:\s*900/);
    assert.match(source, /Qt\.Key_Tab/);
    assert.match(source, /Qt\.Key_Backtab/);
    assert.match(source, /Keys\.onReleased/);
    assert.match(source, /Qt\.Key_Alt/);
});

test("windows utility is built in directly", () => {
    const source = read("K4BuiltinPlugins.qml");
    assert.match(source, /property QtObject windowsPlugin:\s*K4WindowsPlugin\s*\{\}/);
});
