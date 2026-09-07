const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const base = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const hypr = path.join(root, "dots/.config/hypr/hyprland/keybinds.lua");
const read = name => fs.readFileSync(path.join(base, name), "utf8");

test("windows adapter reuses ii-vynx HyprlandData and in-process dispatcher", () => {
    const source = read("K4Windows.qml");
    assert.match(source, /import qs\.services/);
    assert.match(source, /import Quickshell\.Hyprland/);
    assert.match(source, /HyprlandData\.windowList/);
    assert.match(source, /HyprlandData\.updateWindowList/);
    assert.match(source, /Hyprland\.dispatch/);
    assert.doesNotMatch(source, /execDetached/);
});

test("windows plugin keeps pinned k4 priority and dynamic geometry", () => {
    const source = read("K4WindowsPlugin.qml");
    assert.match(source, /name:\s*"windows"/);
    assert.match(source, /priority:\s*83/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /Math\.min\(880,\s*Math\.max\(360,\s*60 \+ count \* 128\)\)/);
    assert.match(source, /islandHeight:\s*190/);
    assert.match(source, /Component\.onCompleted:\s*K4Windows\.plugin = root/);
});

test("window selection no longer depends on local modifier release", () => {
    const source = read("K4WindowsView.qml");
    assert.match(source, /dwellDelay:\s*900/);
    assert.match(source, /Qt\.Key_Tab/);
    assert.match(source, /Qt\.Key_Backtab/);
    assert.doesNotMatch(source, /Keys\.onReleased/);
});

test("K4 routes Super-Tab and Alt-Tab and commits on modifier release", () => {
    const routing = read("K4LauncherRouting.qml");
    const binds = fs.readFileSync(hypr, "utf8");

    assert.match(routing, /name:\s*"overviewWorkspacesToggle"/);
    assert.match(routing, /name:\s*"windowsSwitcherToggle"/);
    assert.match(routing, /name:\s*"windowsSwitcherPrevious"/);
    assert.match(routing, /name:\s*"windowsSwitcherCommit"/);
    assert.match(routing, /K4Windows\.plugin\.choose\(\)/);
    assert.match(routing, /searchToggleRelease[\s\S]*K4Windows\.plugin\.open[\s\S]*K4Windows\.plugin\.choose\(\)/);

    assert.match(binds, /SUPER \+ Tab[\s\S]*overviewWorkspacesToggle/);
    assert.match(binds, /ALT \+ Tab[\s\S]*windowsSwitcherToggle/);
    assert.match(binds, /ALT \+ SHIFT \+ Tab[\s\S]*windowsSwitcherPrevious/);
    assert.match(binds, /ALT_L[\s\S]*windowsSwitcherCommit[\s\S]*release = true/);
    assert.match(binds, /ALT_R[\s\S]*windowsSwitcherCommit[\s\S]*release = true/);
});

test("windows utility is built in directly", () => {
    const source = read("K4BuiltinPlugins.qml");
    assert.match(source, /property QtObject windowsPlugin:\s*K4WindowsPlugin\s*\{\}/);
});
