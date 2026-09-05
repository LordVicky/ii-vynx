const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const k4 = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const overview = path.join(root, "dots/.config/quickshell/ii/modules/ii/overview/Overview.qml");
const hyprlandRoot = path.join(root, "dots/.config/hypr");
const readK4 = name => fs.readFileSync(path.join(k4, name), "utf8");

test("windows adapter stays native to ii-vynx Wayland and Hyprland services", () => {
    const source = readK4("K4Windows.qml");
    assert.match(source, /import Quickshell\.Wayland/);
    assert.match(source, /import Quickshell\.Hyprland/);
    assert.match(source, /HyprlandData\.windowList/);
    assert.match(source, /ToplevelManager\.toplevels/);
    assert.match(source, /Hyprland\.dispatch/);
    assert.match(source, /function toplevelFor\(/);
    assert.match(source, /function windowsForWorkspace\(/);
    assert.doesNotMatch(source, /execDetached/);
    assert.doesNotMatch(source, /hyprctl/);
});

test("windows plugin exposes overview and alt-tab modes", () => {
    const source = readK4("K4WindowsPlugin.qml");
    assert.match(source, /name:\s*"windows"/);
    assert.match(source, /priority:\s*83/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /property string mode:\s*"overview"/);
    assert.match(source, /property bool altTabCurrentWorkspaceOnly:\s*false/);
    assert.match(source, /property int selectedWorkspaceId/);
    assert.match(source, /function openOverview\(/);
    assert.match(source, /function openSwitcher\(/);
    assert.match(source, /function triggerSwitcher\(/);
    assert.match(source, /mode === "overview"/);
    assert.match(source, /altTabCurrentWorkspaceOnly/);
    assert.match(source, /target:\s*"k4\.windows"/);
});

test("windows v2 view uses live Wayland previews and no dwell focus", () => {
    const source = readK4("K4WindowsView.qml");
    assert.match(source, /import Quickshell\.Wayland/);
    assert.match(source, /ScreencopyView/);
    assert.match(source, /captureSource:\s*card\.toplevel/);
    assert.match(source, /root\.plugin\.showWorkspaces/);
    assert.match(source, /K4Workspaces\.list/);
    assert.match(source, /altTabCurrentWorkspaceOnly/);
    assert.match(source, /Keys\.onReleased/);
    assert.match(source, /Qt\.Key_Alt/);
    assert.doesNotMatch(source, /dwellDelay/);
    assert.doesNotMatch(source, /dwellTimer/);
});

test("Super-Tab and Alt-Tab route through Quickshell rather than window scripts", () => {
    const source = fs.readFileSync(overview, "utf8");
    assert.match(source, /import qs\.modules\.ii\.k4bar/);
    assert.match(source, /name:\s*"overviewWorkspacesToggle"/);
    assert.match(source, /K4Windows\.plugin\.toggleOverview\(\)/);
    assert.match(source, /name:\s*"windowsSwitcherToggle"/);
    assert.match(source, /overviewScope\.triggerWindowSwitcher\(1\)/);
    assert.match(source, /name:\s*"windowsSwitcherPrevious"/);
    assert.match(source, /overviewScope\.triggerWindowSwitcher\(-1\)/);

    const entry = fs.readFileSync(path.join(hyprlandRoot, "hyprland.lua"), "utf8");
    const binds = fs.readFileSync(path.join(hyprlandRoot, "hyprland/k4-windows.lua"), "utf8");
    assert.match(entry, /require\("hyprland\.k4-windows"\)/);
    assert.match(binds, /ALT \+ Tab/);
    assert.match(binds, /quickshell:windowsSwitcherToggle/);
    assert.match(binds, /ALT \+ SHIFT \+ Tab/);
    assert.match(binds, /quickshell:windowsSwitcherPrevious/);
    assert.doesNotMatch(binds, /exec_cmd/);
});

test("windows utility is built in directly", () => {
    const source = readK4("K4BuiltinPlugins.qml");
    assert.match(source, /property QtObject windowsPlugin:\s*K4WindowsPlugin\s*\{\}/);
});
