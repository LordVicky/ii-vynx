const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("k4 package adapter keeps package work on-demand and terminal-configured", () => {
    const source = readShell("modules/ii/k4bar/K4Packages.qml");

    assert.match(source, /command = \["pacman", "-Qq"\]/);
    assert.match(source, /repoProcess\.command = \["pacman", "-Ss", "--"\]\.concat/);
    assert.match(source, /aurProcess\.command = \["yay", "-Ss", "--aur", "--color=never", "--"\]\.concat/);
    assert.match(source, /interval:\s*180/);
    assert.match(source, /interval:\s*500/);
    assert.match(source, /Config\.options\.apps\.terminal/);
    assert.match(source, /Quickshell\.execDetached\(\["bash", "-lc"/);
    assert.match(source, /yay -S --needed --/);
    assert.match(source, /sudo pacman -Rns --confirm --/);
    assert.doesNotMatch(source, /running:\s*true[\s\S]*repeat:\s*true/);
    assert.doesNotMatch(source, /property\s+.*packageDatabase/);
});

test("k4 launcher exposes pinned package-mode transitions and IPC", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherPlugin.qml");

    assert.match(source, /property string mode:\s*"apps"/);
    assert.match(source, /readonly property var packageMatches:\s*K4Packages\.matches/);
    assert.match(source, /function enterPackageMode\(\)/);
    assert.match(source, /function leavePackageMode\(\)/);
    assert.match(source, /function schedulePackageSearch\(\)/);
    assert.match(source, /function uninstallSelected\(\)/);
    assert.match(source, /entry && entry\.isInstall === true[\s\S]*?enterPackageMode\(\)/);
    assert.match(source, /function install\(query: string\): void \{ root\.openPackageSearch\(query\) \}/);
    assert.match(source, /K4Packages\.reset\(\)/);
});

test("k4 launcher package view preserves keyboard and row actions", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherView.qml");

    assert.match(source, /root\.plugin\.mode === "packages"[\s\S]*?"Search packages to install"/);
    assert.match(source, /root\.plugin\.mode === "packages"[\s\S]*?root\.plugin\.schedulePackageSearch\(\)/);
    assert.match(source, /Qt\.Key_Escape[\s\S]*?root\.plugin\.leavePackageMode\(\)/);
    assert.match(source, /Qt\.Key_Delete[\s\S]*?Qt\.ControlModifier[\s\S]*?root\.plugin\.uninstallSelected\(\)/);
    assert.match(source, /model:\s*root\.plugin\.packageMatches/);
    assert.match(source, /packageRow\.modelData\.repo === "aur"/);
    assert.match(source, /packageRow\.modelData\.installed \? "update ↵" : "install ↵"/);
    assert.match(source, /onClicked:\s*root\.plugin\.uninstallPackage\(packageRow\.modelData\)/);
});
