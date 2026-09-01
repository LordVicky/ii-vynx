const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");
const readRepo = relative => fs.readFileSync(path.join(repoRoot, relative), "utf8");
const executableSource = source => source.replace(/^\s*\/\/.*$/gm, "");

test("k4 visual tokens preserve the pinned upstream collapsed geometry", () => {
    const theme = readShell("modules/ii/k4bar/K4Theme.qml");

    assert.match(theme, /readonly property color islandBg:\s*"#000000"/);
    assert.match(theme, /readonly property int wing:\s*16/);
    assert.match(theme, /readonly property int baseHeight:\s*34/);
    assert.match(theme, /readonly property int maxIslandHeight:\s*880/);
});

test("island shell uses inverse wings, bottom reflection and stable surface sizing", () => {
    const source = readShell("modules/ii/k4bar/K4Bar.qml");

    assert.match(source, /import QtQuick\.Shapes/);
    assert.match(source, /Shape\s*\{[\s\S]*?layer\.samples:\s*8/);
    assert.match(source, /ShapePath\s*\{/);
    assert.match(source, /PathArc\s*\{[\s\S]*?direction:\s*PathArc\.Clockwise/);
    assert.match(source, /yScale:\s*panelWindow\.bottom \? -1 : 1/);
    assert.match(source, /readonly property string effectiveSpaceMode:\s*K4Settings\.spaceMode === "fullscreen"/);
    assert.match(source, /exclusiveZone:\s*panelWindow\.effectiveSpaceMode === "reserve"[\s\S]*?\? K4Theme\.baseHeight \+ panelWindow\.shapeInset : 0/);
    assert.match(source, /property int surfaceHeight:\s*targetHeight/);
    assert.match(source, /interval:\s*520[\s\S]*?surfaceHeight = panelWindow\.targetHeight/);
    assert.match(source, /Behavior on width[\s\S]*?duration:\s*440[\s\S]*?Easing\.OutBack/);
    assert.match(source, /Behavior on height[\s\S]*?duration:\s*400[\s\S]*?Easing\.OutBack/);
    assert.match(source, /mask:\s*Region\s*\{[\s\S]*?item:\s*IslandState\.suppressed \? null : island/);
});

test("collapsed pill keeps the clock centered and indicators pinned right", () => {
    const source = readShell("modules/ii/k4bar/K4IdlePill.qml");

    assert.match(source, /readonly property bool trayReserveActive:\s*K4Settings\.trayInPill[\s\S]*?K4TrayHost\.plugin !== null && K4Tray\.count > 0/);
    assert.match(source, /readonly property int leftMeasured:\s*isPlaying[\s\S]*?leftMedia\.implicitWidth > 0[\s\S]*?Math\.ceil\(leftMedia\.implicitWidth\)[\s\S]*?: 53[\s\S]*?: 0/);
    assert.match(source, /readonly property int rightMeasured:[\s\S]*?trayReserveActive \? Math\.ceil\(collapsedTray\.implicitWidth\) : 0[\s\S]*?recording \? Math\.ceil\(recordingRow\.implicitWidth\) : 0[\s\S]*?trayReserveActive && recording \? rightIndicators\.spacing : 0/);
    assert.match(source, /readonly property int sideMeasured:\s*Math\.max\(leftMeasured, rightMeasured\)/);
    assert.match(source, /readonly property int desiredBodyWidth:\s*sideMeasured \* 2 \+ 90/);
    assert.match(source, /RowLayout\s*\{[\s\S]*?id:\s*leftMedia[\s\S]*?anchors\.left:\s*parent\.left/);
    assert.match(source, /Item\s*\{[\s\S]*?id:\s*centerZone[\s\S]*?anchors\.horizontalCenter:\s*parent\.horizontalCenter[\s\S]*?width:\s*46/);
    assert.match(source, /id:\s*rightIndicators[\s\S]*?anchors\.right:\s*parent\.right/);
    assert.doesNotMatch(source, /anchors\.leftMargin:\s*root\.leftMeasured \+ 11/);
});

test("idle media lifecycle and workspace behavior follows k4 defaults", () => {
    const source = readShell("modules/ii/k4bar/K4IdlePill.qml");
    const media = readShell("modules/ii/k4bar/K4Media.qml");
    const executableMedia = executableSource(media);

    assert.match(source, /readonly property var activePlayer:\s*K4Media\.activePlayer/);
    assert.match(source, /readonly property bool isPlaying:\s*K4Media\.isPlaying/);
    assert.match(source, /K4Media\.coverFor\(activePlayer\)/);
    assert.match(source, /readonly property var workspaces:\s*K4Workspaces\.list/);
    assert.match(source, /readonly property int activeWorkspaceId:\s*K4Workspaces\.activeId/);
    assert.match(source, /target:\s*K4Workspaces[\s\S]*?onActiveIdChanged[\s\S]*?onListChanged/);
    assert.match(source, /Qt\.formatDateTime\(K4Clock\.date, "HH:mm"\)/);

    assert.match(media, /const players = Mpris\.players\.values/);
    assert.match(media, /if \(players\[i\]\.isPlaying\)[\s\S]*?return players\[i\]/);
    assert.match(media, /return players\.length > 0 \? players\[0\] : null/);
    assert.doesNotMatch(executableMedia, /MprisController\.activePlayer/);

    assert.match(source, /visible:\s*root\.isPlaying/);
    assert.match(source, /model:\s*4/);
    assert.match(source, /SequentialAnimation on height[\s\S]*?running:\s*root\.isPlaying/);
    assert.match(source, /interval:\s*700[\s\S]*?root\.started = true/);
    assert.match(source, /interval:\s*1800[\s\S]*?root\.showingWorkspaces = false/);
    assert.match(source, /workspaces\.slice\(workspaceStart, workspaceStart \+ 3\)/);
    assert.match(source, /opacity:\s*root\.showingWorkspaces \? 0 : 1/);
});

test("explicit island owners consume passive hover without an activePlugin binding loop", () => {
    const controller = executableSource(readShell("modules/ii/k4bar/K4PluginController.qml"));
    const builtins = executableSource(readShell("modules/ii/k4bar/K4BuiltinPlugins.qml"));

    assert.match(controller, /property bool passiveHoverAllowed:\s*false/);
    assert.match(controller, /readonly property bool passiveHoverEffective:\s*K4Settings\.expandIdleOnHover[\s\S]*?&& passiveHoverAllowed/);
    assert.match(controller, /K4BuiltinPlugins\s*\{[\s\S]*?passiveHoverAllowed:\s*root\.passiveHoverEffective/);
    assert.match(controller, /function isAmbientPlugin\(candidate\)[\s\S]*?candidate\.transitorio[\s\S]*?isPassiveHoverPlugin\(candidate\)/);
    assert.match(controller, /function schedulePassiveHoverSuppression\(\)[\s\S]*?Qt\.callLater\(function\(\)[\s\S]*?root\.passiveHoverAllowed = false/);
    assert.match(controller, /function publishActivePlugin\(\)[\s\S]*?dismissTransients\(\)[\s\S]*?schedulePassiveHoverSuppression\(\)/);
    assert.doesNotMatch(controller, /if \(activePlugin && !isAmbientPlugin\(activePlugin\)\)\s*passiveHoverAllowed = false/);
    assert.match(controller, /const newHoverSession = !IslandState\.hovered[\s\S]*?if \(newHoverSession\)\s*passiveHoverAllowed = isAmbientPlugin\(activePlugin\)/);
    assert.match(controller, /onTriggered:\s*\{[\s\S]*?IslandState\.hovered = false[\s\S]*?root\.passiveHoverAllowed = false/);

    assert.match(builtins, /property bool passiveHoverAllowed:\s*false/);
    assert.match(builtins, /name:\s*"clock"[\s\S]*?active:\s*enabled && IslandState\.hovered && root\.passiveHoverAllowed/);
    assert.match(builtins, /name:\s*"player"[\s\S]*?active:\s*enabled && \([\s\S]*?IslandState\.hovered && root\.passiveHoverAllowed[\s\S]*?\|\| trackPeekOpen/);
});

test("recording indicator stays inline with the idle pill", () => {
    const source = readShell("modules/ii/k4bar/K4IdlePill.qml");

    assert.match(source, /^import qs\.modules\.common$/m);
    assert.match(source, /Persistent\.states\.screenRecord\.active/);
    assert.match(source, /Persistent\.states\.screenRecord\.seconds/);
    assert.match(source, /color:\s*K4Theme\.red/);
    assert.match(source, /loops:\s*Animation\.Infinite/);
});

test("k4-derived code carries repository attribution", () => {
    const notice = readRepo("licenses/k4-NOTICE.txt");
    const host = readShell("modules/ii/k4bar/K4Bar.qml");
    const idle = readShell("modules/ii/k4bar/K4IdlePill.qml");

    assert.match(notice, /Copyright \(c\) 2026 k4ditano/);
    assert.match(notice, /48993812c88f0af5d0c5345cd273467043b889f1/);
    assert.match(host, /licenses\/k4-NOTICE\.txt/);
    assert.match(idle, /licenses\/k4-NOTICE\.txt/);
});
