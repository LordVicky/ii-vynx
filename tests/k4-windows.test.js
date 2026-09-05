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

test("Super-Tab always starts from the focused monitor workspace", () => {
    const workspaces = readK4("K4Workspaces.qml");
    const plugin = readK4("K4WindowsPlugin.qml");

    assert.match(workspaces, /Hyprland\.focusedMonitor\?\.activeWorkspace\?\.id/);
    assert.match(plugin, /selectedWorkspaceId = K4Workspaces\.activeId > 0/);
});

test("Super-Tab exposes a continuous scrollable workspace range", () => {
    const workspaces = readK4("K4Workspaces.qml");
    const view = readK4("K4WindowsView.qml");

    assert.match(workspaces, /minimumOverviewWorkspaces:\s*10/);
    assert.match(workspaces, /readonly property var overviewList/);
    assert.match(workspaces, /for \(let id = 1; id <= highestId; \+\+id\)/);
    assert.match(view, /model:\s*K4Workspaces\.overviewList/);
    assert.match(view, /flickableDirection:\s*Flickable\.VerticalFlick/);
    assert.match(view, /id:\s*workspaceScrollThumb/);
    assert.match(view, /workspaceList\.contentHeight > workspaceList\.height/);
    assert.match(view, /positionViewAtIndex\(index, ListView\.Contain\)/);
});

test("repeated Super-Tab cycles only workspaces that contain windows", () => {
    const plugin = readK4("K4WindowsPlugin.qml");

    assert.match(plugin, /function occupiedWorkspaceIds\(/);
    assert.match(plugin, /K4Workspaces\.overviewList/);
    assert.match(plugin, /K4Windows\.windowCountForWorkspace\(id\) > 0/);
    assert.match(plugin, /function cycleOverviewWorkspace\(/);
    assert.match(plugin, /if \(open && mode === "overview"\)[\s\S]*?cycleOverviewWorkspace\(1\)/);
});

test("fullscreen clients occupy the whole overview workspace but remain interactive", () => {
    const adapter = readK4("K4Windows.qml");
    const layout = readK4("K4WorkspaceLayout.qml");

    assert.match(adapter, /function isFullscreen\(/);
    assert.match(adapter, /if \(root\.isFullscreen\(window\)\)/);
    assert.match(adapter, /return \(\{ x: 0, y: 0, width: 1, height: 1 \}\)/);
    assert.match(layout, /readonly property bool fullscreen:/);
    assert.match(layout, /K4Windows\.isFullscreen\(windowItem\.modelData\)/);
    assert.match(layout, /z: windowItem\.dragging \? 1000/);
    assert.match(layout, /MouseArea \{/);
    assert.match(layout, /root\.moveRequested\(row, targetWorkspace\)/);
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

test("modifier release commits only an armed Super-Tab or Alt-Tab session", () => {
    const plugin = readK4("K4WindowsPlugin.qml");
    const routing = readK4("K4LauncherRouting.qml");
    const binds = fs.readFileSync(path.join(hyprlandRoot, "hyprland/k4-windows.lua"), "utf8");

    assert.match(plugin, /property string releaseCommitModifier:\s*""/);
    assert.match(plugin, /function armReleaseCommit\(modifier\)/);
    assert.match(plugin, /function commitRelease\(modifier\)/);
    assert.match(plugin, /if \(!open \|\| releaseCommitModifier !== value\)/);
    assert.match(plugin, /releaseCommitModifier = ""[\s\S]*?chooseWindow\(row\)/);
    assert.match(plugin, /function close\(\)[\s\S]*?releaseCommitModifier = ""/);

    assert.match(routing, /function toggleWindowsOverview\(\)[\s\S]*?armReleaseCommit\("super"\)/);
    assert.match(routing, /function triggerWindowSwitcher\(direction\)[\s\S]*?armReleaseCommit\("alt"\)/);
    assert.match(routing, /name:\s*"windowsSwitcherModifier"/);
    assert.match(routing, /name:\s*"windowsSwitcherModifier"[\s\S]*?onReleased:[\s\S]*?commitRelease\("alt"\)/);
    assert.match(routing, /name:\s*"searchToggleRelease"[\s\S]*?commitRelease\("super"\)/);

    assert.match(binds, /ALT \+ ALT_L/);
    assert.match(binds, /ALT \+ ALT_R/);
    assert.match(binds, /quickshell:windowsSwitcherModifier/);
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

test("workspace canvases reuse the current ii-vynx wallpaper", () => {
    const layout = readK4("K4WorkspaceLayout.qml");

    assert.match(layout, /Config\.options\.background\.thumbnailPath/);
    assert.match(layout, /Config\.options\.background\.wallpaperPath/);
    assert.match(layout, /id:\s*workspaceWallpaper/);
    assert.match(layout, /fillMode:\s*Image\.PreserveAspectCrop/);
    assert.match(layout, /mipmap:\s*true/);
});

test("live K4 window previews use smooth mipmapped downsampling", () => {
    const layout = readK4("K4WorkspaceLayout.qml");
    const view = readK4("K4WindowsView.qml");

    for (const source of [layout, view]) {
        assert.match(source, /ScreencopyView[\s\S]*?smooth:\s*true/);
        assert.match(source, /layer\.enabled:\s*true/);
        assert.match(source, /layer\.smooth:\s*true/);
        assert.match(source, /layer\.mipmap:\s*true/);
    }
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
