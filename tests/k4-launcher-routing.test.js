const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("standard Overview and K4 launcher routing are mutually exclusive at the family boundary", () => {
    const source = readShell("panelFamilies/IllogicalImpulseFamily.qml");

    assert.match(source, /PanelLoader \{ extraCondition: usingK4Bar; component: K4Bar \{\} \}/);
    assert.match(source, /PanelLoader \{ extraCondition: usingK4Bar; component: K4LauncherRouting \{\} \}/);
    assert.match(source, /PanelLoader \{ extraCondition: usingStandardBar; component: Overview \{\} \}/);
    assert.doesNotMatch(source, /PanelLoader \{ component: Overview \{\} \}/);
});

test("K4 routing imports the Hyprland shortcut provider", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherRouting.qml");

    assert.match(source, /^import Quickshell\.Hyprland$/m);
});

test("K4 routing reuses the existing search shortcut and IPC names without opening ii Overview", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherRouting.qml");

    assert.match(source, /Component\.onCompleted:\s*GlobalStates\.overviewOpen = false/);
    assert.match(source, /Component\.onDestruction:[\s\S]*?K4Launcher\.close\(\)[\s\S]*?K4Clipboard\.closeSurface\(\)/);
    assert.match(source, /onOverviewOpenChanged\(\)[\s\S]*?GlobalStates\.overviewOpen = false/);
    assert.match(source, /target:\s*"search"/);
    assert.match(source, /function toggle\(\): void \{ K4Launcher\.toggle\(\) \}/);
    assert.match(source, /function open\(\): void \{ K4Launcher\.openSearch\(""\) \}/);
    assert.match(source, /function close\(\): void[\s\S]*?K4Launcher\.close\(\)[\s\S]*?K4Clipboard\.closeSurface\(\)/);
    assert.match(source, /name:\s*"searchToggle"[\s\S]*?onPressed:\s*K4Launcher\.toggle\(\)/);
    assert.match(source, /name:\s*"searchToggleRelease"[\s\S]*?onReleased:[\s\S]*?K4Launcher\.toggle\(\)/);
    assert.match(source, /name:\s*"searchToggleReleaseInterrupt"[\s\S]*?GlobalStates\.superReleaseMightTrigger = false/);
    assert.doesNotMatch(source, /GlobalStates\.overviewOpen = true/);
});

test("K4 routing preserves the existing Super+V clipboard shortcut and search IPC", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherRouting.qml");

    assert.match(source, /function clipboardToggle\(\): void \{ K4Clipboard\.toggleSurface\(\) \}/);
    assert.match(source, /name:\s*"overviewClipboardToggle"[\s\S]*?onPressed:\s*K4Clipboard\.toggleSurface\(\)/);
});
