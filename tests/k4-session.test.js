const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const base = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(base, name), "utf8");

test("session adapter delegates actions to the existing ii session owner", () => {
    const source = read("K4Session.qml");
    assert.match(source, /import qs\.modules\.common\.functions/);
    assert.match(source, /Session\.lock\(\)/);
    assert.match(source, /Session\.suspend\(\)/);
    assert.match(source, /Session\.hibernate\(\)/);
    assert.match(source, /Session\.logout\(\)/);
    assert.match(source, /Session\.reboot\(\)/);
    assert.match(source, /Session\.poweroff\(\)/);
    assert.doesNotMatch(source, /GlobalStates\.screenLocked|Quickshell\.execDetached|hyprctl|systemctl/);
    assert.doesNotMatch(source, /WlSessionLock|SessionLock|LockSurface/);
});

test("session plugin preserves upstream priority, dynamic width and confirmation", () => {
    const source = read("K4SessionPlugin.qml");
    assert.match(source, /name:\s*"session"/);
    assert.match(source, /priority:\s*86/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /Math\.min\(760,\s*40 \+ count \* 118\)/);
    assert.match(source, /islandHeight:\s*200/);
    assert.match(source, /action\.confirm && confirming !== i/);
    assert.match(source, /target:\s*"k4\.session"/);
});

test("session utility is registered directly as a built-in", () => {
    const source = read("K4BuiltinPlugins.qml");
    assert.match(source, /property QtObject sessionPlugin:\s*K4SessionPlugin\s*\{\}/);
});
