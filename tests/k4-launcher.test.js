const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("k4 desktop-app adapter reuses ii application ownership", () => {
    const source = readShell("modules/ii/k4bar/K4DesktopApps.qml");

    assert.match(source, /AppSearch\.fuzzyQuery\(normalized\)/);
    assert.match(source, /Array\.from\(AppSearch\.list\)/);
    assert.match(source, /!entry\.noDisplay/);
    assert.match(source, /entry\.execute\(\)/);
    assert.match(source, /Config\.options\.apps\.terminal/);
    assert.doesNotMatch(source, /DesktopEntries/);
    assert.doesNotMatch(source, /\bProcess\s*\{/);
    assert.doesNotMatch(source, /update-desktop-database/);
});

test("k4 desktop-app results snapshot values and resolve a fresh entry for launch", () => {
    const source = readShell("modules/ii/k4bar/K4DesktopApps.qml");

    assert.match(source, /function snapshot\(entry\)/);
    assert.match(source, /id:\s*String\(entry\.id \?\? ""\)/);
    assert.match(source, /name:\s*String\(entry\.name \?\? ""\)/);
    assert.match(source, /icon:\s*String\(entry\.icon \?\? ""\)/);
    assert.match(source, /runInTerminal:\s*Boolean\(entry\.runInTerminal\)/);
    assert.match(source, /command:\s*Array\.from\(entry\.command \?\? \[\]\)/);
    assert.match(source, /visible\.slice\(0, resultLimit\)\.map\(entry => root\.snapshot\(entry\)\)/);
    assert.match(source, /function resolve\(row\)[\s\S]*?AppSearch\.list\.find\(entry => entry && entry\.id === row\.id\) \?\? null/);
    assert.match(source, /function launch\(row\)[\s\S]*?const entry = root\.resolve\(row\)[\s\S]*?if \(!entry\)[\s\S]*?return/);
    assert.doesNotMatch(source, /return visible\.slice\(0, resultLimit\)\s*$/m);
});

test("k4 launcher preserves island ownership and keyboard lifecycle", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherPlugin.qml");

    assert.match(source, /name:\s*"launcher"/);
    assert.match(source, /priority:\s*80/);
    assert.match(source, /active:\s*enabled && open/);
    assert.match(source, /viewLoaded:\s*open/);
    assert.match(source, /grabKeyboard:\s*open/);
    assert.match(source, /islandWidth:\s*720/);
    assert.match(source, /islandHeight:\s*440/);
    assert.match(source, /K4Panel\.close\(\)/);
    assert.match(source, /K4Notifications\.dismissToast\(\)/);
    assert.match(source, /K4DesktopApps\.search\(query\)/);
    assert.match(source, /K4DesktopApps\.launch\(entry\)/);
    assert.match(source, /function onNotify\(notification\) \{ root\.yieldToNotification\(\) \}/);
    assert.match(source, /target:\s*"k4\.launcher"/);
});

test("k4 launcher releases ownership immediately on close", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherPlugin.qml");

    assert.doesNotMatch(source, /property\s+bool\s+closing\b/);
    assert.doesNotMatch(source, /\bid:\s*closeTimer\b/);
    assert.match(source, /function close\(\)[\s\S]*?if \(!open\)[\s\S]*?open = false[\s\S]*?query = ""/);
});

test("k4 launcher rebuilds before activation and clears rows on every close path", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherPlugin.qml");
    const openSearch = source.match(/function openSearch\(initial = ""\) \{([\s\S]*?)\n    \}/)?.[1] ?? "";
    const close = source.match(/function close\(\) \{([\s\S]*?)\n    \}/)?.[1] ?? "";
    const yieldToNotification = source.match(/function yieldToNotification\(\) \{([\s\S]*?)\n    \}/)?.[1] ?? "";

    assert.ok(openSearch.indexOf("rebuild()") >= 0);
    assert.ok(openSearch.indexOf("rebuild()") < openSearch.indexOf("open = true"));
    assert.match(close, /open = false[\s\S]*?query = ""[\s\S]*?matches = \[\]/);
    assert.match(yieldToNotification, /open = false[\s\S]*?query = ""[\s\S]*?matches = \[\]/);
});

test("k4 launcher view keeps the spotlight interaction model with viewport hover", () => {
    const source = readShell("modules/ii/k4bar/K4LauncherView.qml");

    assert.match(source, /text:\s*"Search applications"/);
    assert.match(source, /Qt\.Key_Escape[\s\S]*?root\.plugin\.close\(\)/);
    assert.match(source, /Qt\.Key_Return \|\| event\.key === Qt\.Key_Enter[\s\S]*?root\.plugin\.launchSelected\(\)/);
    assert.match(source, /Qt\.Key_Down[\s\S]*?root\.plugin\.moveSelection\(1\)/);
    assert.match(source, /Qt\.Key_Up[\s\S]*?root\.plugin\.moveSelection\(-1\)/);
    assert.match(source, /IconImage[\s\S]*?Quickshell\.iconPath\(appRow\.modelData\.icon/);
    assert.match(source, /K4CursorTrackedListView\s*\{[\s\S]*?id:\s*appResults[\s\S]*?rowHeight:\s*42/);
    assert.match(source, /onHoveredIndexChanged:[\s\S]*?root\.plugin\.index\s*=\s*hoveredIndex/);
    assert.doesNotMatch(source, /onEntered:\s*root\.plugin\.index\s*=\s*appRow\.index/);
    assert.match(source, /onClicked:[\s\S]*?root\.plugin\.launchSelected\(\)/);
});

test("k4 launcher stays within the approved launcher/apps shell boundary", () => {
    const plugin = readShell("modules/ii/k4bar/K4LauncherPlugin.qml");
    const view = readShell("modules/ii/k4bar/K4LauncherView.qml");
    const packagesPath = path.join(shellRoot, "modules/ii/k4bar/K4Packages.qml");

    assert.equal(fs.existsSync(packagesPath), false);
    assert.doesNotMatch(plugin, /K4Packages|openPackageSearch|enterPackageMode|uninstallPackage|\bpacman\b|\byay\b/);
    assert.doesNotMatch(view, /K4Packages|packageResults|Search packages|searching AUR|\buninstall\b/);
});

test("k4 launcher bridge follows the existing panel-style singleton seam", () => {
    const source = readShell("modules/ii/k4bar/K4Launcher.qml");

    assert.match(source, /^\s*import Quickshell\s*$/m);
    assert.match(source, /property var plugin:\s*null/);
    assert.match(source, /function toggle\(\)/);
    assert.match(source, /function openSearch\(query = ""\)/);
    assert.match(source, /function close\(\)/);
    assert.match(source, /pendingOpen/);
});

test("k4 builtin registry exposes the launcher plugin", () => {
    const source = readShell("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(source, /plugins:\s*\[[\s\S]*?launcherPlugin/);
    assert.match(source, /property QtObject launcherPlugin:\s*K4LauncherPlugin \{\}/);
});
