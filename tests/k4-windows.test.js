const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const k4 = path.join(root, "dots/.config/quickshell/ii/modules/ii/k4bar");
const overviewPath = path.join(root, "dots/.config/quickshell/ii/modules/ii/overview/Overview.qml");
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
    assert.match(source, /function switcherWindows\(/);
    assert.match(source, /function activate\(/);
    assert.match(source, /function close\(/);
    assert.doesNotMatch(source, /execDetached/);
    assert.doesNotMatch(source, /hyprctl/);
});

test("K4 Windows is an Alt-Tab switcher only", () => {
    const source = readK4("K4WindowsPlugin.qml");
    assert.match(source, /name:\s*"windows"/);
    assert.match(source, /priority:\s*83/);
    assert.match(source, /application:\s*true/);
    assert.match(source, /property bool altTabCurrentWorkspaceOnly:\s*false/);
    assert.match(source, /function openSwitcher\(/);
    assert.match(source, /function triggerSwitcher\(/);
    assert.match(source, /islandHeight:\s*320/);
    assert.match(source, /target:\s*"k4\.windows"/);
    assert.doesNotMatch(source, /openOverview|toggleOverview|cycleOverviewWorkspace|selectedWorkspaceId|showWorkspaces/);
});

test("Alt-Tab keeps the windows-only live Wayland preview switcher", () => {
    const source = readK4("K4WindowsView.qml");
    assert.match(source, /import Quickshell\.Wayland/);
    assert.match(source, /ScreencopyView/);
    assert.match(source, /model:\s*root\.plugin\.entries/);
    assert.match(source, /altTabCurrentWorkspaceOnly/);
    assert.match(source, /cellWidth:\s*260/);
    assert.doesNotMatch(source, /K4WorkspaceLayout|workspaceRail|selectedWorkspaceId|showWorkspaces/);
    assert.doesNotMatch(source, /dwellDelay|dwellTimer/);
});

test("stock ii-vynx Overview solely owns Super-Tab workspace management", () => {
    const overview = fs.readFileSync(overviewPath, "utf8");
    const familySource = fs.readFileSync(family, "utf8");

    assert.match(familySource, /PanelLoader \{ component: Overview \{\} \}/);
    assert.doesNotMatch(familySource, /K4LauncherRouting/);
    assert.match(overview, /name:\s*"overviewWorkspacesToggle"/);
    assert.match(overview, /GlobalStates\.overviewOpen = !GlobalStates\.overviewOpen/);
    assert.match(overview, /sourceComponent:\s*OverviewWidget/);
    assert.match(overview, /sourceComponent:\s*ScrollingOverviewWidget/);
    assert.doesNotMatch(overview, /toggleOverview\(|openOverview\(|armReleaseCommit\("super"\)|commitRelease\("super"\)/);
    assert.equal(fs.existsSync(path.join(k4, "K4WorkspaceLayout.qml")), false);
    assert.equal(fs.existsSync(path.join(k4, "K4LauncherRouting.qml")), false);
});

test("Alt modifier release commits only the armed K4 switcher selection", () => {
    const plugin = readK4("K4WindowsPlugin.qml");
    const overview = fs.readFileSync(overviewPath, "utf8");
    const binds = fs.readFileSync(path.join(hyprlandRoot, "hyprland/k4-windows.lua"), "utf8");

    assert.match(plugin, /property bool releaseCommitArmed:\s*false/);
    assert.match(plugin, /function armReleaseCommit\(\)/);
    assert.match(plugin, /function commitRelease\(\)/);
    assert.match(plugin, /chooseWindow\(row\)/);
    assert.match(overview, /name:\s*"windowsSwitcherToggle"/);
    assert.match(overview, /K4Windows\.plugin\.triggerSwitcher\(1\)/);
    assert.match(overview, /name:\s*"windowsSwitcherPrevious"/);
    assert.match(overview, /K4Windows\.plugin\.triggerSwitcher\(-1\)/);
    assert.match(overview, /name:\s*"windowsSwitcherModifier"[\s\S]*?commitRelease\(\)/);

    assert.match(binds, /ALT \+ Tab/);
    assert.match(binds, /ALT \+ SHIFT \+ Tab/);
    assert.match(binds, /quickshell:windowsSwitcherModifier/);
    assert.doesNotMatch(binds, /SUPER/);
    assert.doesNotMatch(binds, /exec_cmd/);
});

test("windows utility is built in directly", () => {
    const source = readK4("K4BuiltinPlugins.qml");
    assert.match(source, /property QtObject windowsPlugin:\s*K4WindowsPlugin\s*\{\}/);
});
