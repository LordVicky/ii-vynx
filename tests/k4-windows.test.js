const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const k4 = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const family = path.join(root, "dots/.config/quickshell/ii/panelFamilies/IllogicalImpulseFamily.qml");
const hyprlandRoot = path.join(root, "dots/.config/hypr");
const readK4 = name => fs.readFileSync(path.join(k4, name), "utf8");

test("windows adapter stays on ii-vynx Wayland and Hyprland ownership seams", () => {
    const source = readK4("K4Windows.qml");
    assert.match(source, /import Quickshell\.Wayland/);
    assert.match(source, /import Quickshell\.Hyprland/);
    assert.match(source, /HyprlandData\.windowList/);
    assert.match(source, /ToplevelManager\.toplevels/);
    assert.match(source, /Hyprland\.dispatch/);
    assert.match(source, /function toplevelFor\(/);
    assert.match(source, /function windowsForWorkspace\(/);
    assert.match(source, /function monitorForWorkspace\(/);
    assert.match(source, /function workspaceGeometry\(/);
    assert.match(source, /function windowGeometry\(/);
    assert.match(source, /function moveToWorkspace\(/);
    assert.match(source, /function swapWindows\(/);
    assert.doesNotMatch(source, /execDetached/);
    assert.doesNotMatch(source, /hyprctl/);
});

test("windows plugin exposes overview and alt-tab modes with enlarged geometry", () => {
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
    assert.match(source, /islandWidth:\s*showWorkspaces[\s\S]*?1120/);
    assert.match(source, /islandHeight:\s*showWorkspaces \? 560 : 320/);
    assert.match(source, /target:\s*"k4\.windows"/);
});

test("workspace layout mirrors Hyprland geometry with live Wayland previews", () => {
    const source = readK4("K4WorkspaceLayout.qml");
    assert.match(source, /required property int workspaceId/);
    assert.match(source, /K4Windows\.workspaceGeometry\(root\.workspaceId\)/);
    assert.match(source, /K4Windows\.windowGeometry\(windowItem\.modelData/);
    assert.match(source, /ScreencopyView/);
    assert.match(source, /captureSource:\s*windowItem\.toplevel/);
    assert.match(source, /x:\s*windowItem\.layoutX/);
    assert.match(source, /y:\s*windowItem\.layoutY/);
    assert.match(source, /width:\s*windowItem\.layoutWidth/);
    assert.match(source, /height:\s*windowItem\.layoutHeight/);
});

test("Super-Tab drag uses the proven ii-vynx imperative Drag lifecycle", () => {
    const source = readK4("K4WorkspaceLayout.qml");
    const view = readK4("K4WindowsView.qml");

    assert.match(source, /windowItem\.Drag\.active = true/);
    assert.match(source, /windowItem\.Drag\.source = windowItem/);
    assert.match(source, /windowItem\.Drag\.hotSpot\.x = mouse\.x/);
    assert.match(source, /windowItem\.Drag\.hotSpot\.y = mouse\.y/);
    assert.match(source, /const targetWorkspace = root\.draggingTargetWorkspace/);
    assert.match(source, /windowItem\.Drag\.active = false/);
    assert.match(source, /root\.moveRequested\(row, targetWorkspace\)/);
    assert.match(view, /DropArea/);
    assert.match(view, /root\.draggingTargetWorkspace = workspaceCard\.workspaceId/);
    assert.match(view, /K4Windows\.moveToWorkspace\(row, targetWorkspace\)/);
});

test("Super-Tab can reorder tiled windows inside a workspace like ii-vynx overview", () => {
    const source = readK4("K4WorkspaceLayout.qml");
    const adapter = readK4("K4Windows.qml");

    assert.match(source, /property var draggingTargetWindow/);
    assert.match(source, /property string draggingDirection/);
    assert.match(source, /DropArea/);
    assert.match(source, /drag\.x < width \/ 2 \? "l" : "r"/);
    assert.match(source, /K4Windows\.swapWindows\(row, targetRow, direction\)/);
    assert.match(adapter, /hl\.dsp\.layout\(`swapaddrdir/);
});

test("Alt-Tab keeps the windows-only live preview switcher", () => {
    const source = readK4("K4WindowsView.qml");
    assert.match(source, /id:\s*switcherGrid/);
    assert.match(source, /model:\s*root\.plugin\.entries/);
    assert.match(source, /ScreencopyView/);
    assert.match(source, /altTabCurrentWorkspaceOnly/);
    assert.match(source, /Keys\.onReleased/);
    assert.match(source, /Qt\.Key_Alt/);
    assert.doesNotMatch(source, /dwellDelay/);
    assert.doesNotMatch(source, /dwellTimer/);
});

test("K4-only routing owns Super-Tab and Alt-Tab while K4 is loaded", () => {
    const routing = readK4("K4LauncherRouting.qml");
    const familySource = fs.readFileSync(family, "utf8");

    assert.match(familySource, /extraCondition:\s*barEnabled && usingK4Bar; component:\s*K4LauncherRouting \{\}/);
    assert.match(familySource, /extraCondition:\s*usingStandardBar; component:\s*Overview \{\}/);

    assert.match(routing, /name:\s*"overviewWorkspacesToggle"/);
    assert.match(routing, /K4Windows\.plugin\.toggleOverview\(\)/);
    assert.match(routing, /name:\s*"windowsSwitcherToggle"/);
    assert.match(routing, /K4Windows\.plugin\.triggerSwitcher\(1\)/);
    assert.match(routing, /name:\s*"windowsSwitcherPrevious"/);
    assert.match(routing, /K4Windows\.plugin\.triggerSwitcher\(-1\)/);

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
