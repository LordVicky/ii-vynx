const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");
const executableSource = source => source.replace(/^\s*\/\/.*$/gm, "");

test("media adapter preserves live MPRIS lifecycle and watcher-gated position updates", () => {
    const source = read("modules/ii/k4bar/K4Media.qml");
    const executable = executableSource(source);

    assert.match(source, /const players = Mpris\.players\.values/);
    assert.match(source, /players\[i\]\.isPlaying/);
    assert.match(source, /return players\.length > 0 \? players\[0\] : null/);
    assert.doesNotMatch(executable, /MprisController/);

    assert.match(source, /property int positionWatchers:\s*0/);
    assert.match(source, /function watchPosition\(\)[\s\S]*?positionWatchers \+= 1/);
    assert.match(source, /function unwatchPosition\(\)[\s\S]*?Math\.max\(0, positionWatchers - 1\)/);
    assert.match(source, /interval:\s*500[\s\S]*?running:\s*root\.isPlaying && root\.positionWatchers > 0/);

    assert.match(source, /property bool hasTimeline:\s*false/);
    assert.match(source, /id:\s*timelineDropTimer[\s\S]*?interval:\s*1500/);
    assert.match(source, /function seekTo\(fraction\)[\s\S]*?player\.position = Math\.max\(0, Math\.min\(1, fraction\)\) \* player\.length/);
    assert.match(source, /function previous\(\)[\s\S]*?activePlayer\.previous\(\)/);
    assert.match(source, /function next\(\)[\s\S]*?activePlayer\.next\(\)/);
    assert.match(source, /function togglePlaying\(\)[\s\S]*?activePlayer\.togglePlaying\(\)/);
});

test("audio adapter layers HUD timing on ii Audio without another PipeWire owner", () => {
    const source = read("modules/ii/k4bar/K4Audio.qml");
    const osd = read("modules/ii/onScreenDisplay/OnScreenDisplay.qml");

    assert.match(source, /import qs\.services/);
    assert.match(source, /readonly property var sink:\s*Audio\.sink/);
    assert.doesNotMatch(source, /PwObjectTracker|Pipewire\.|Process\s*\{/);

    assert.match(source, /property bool initialized:\s*false/);
    assert.match(source, /const changed = initialized[\s\S]*?nextVolume !== volume \|\| nextMuted !== muted/);
    assert.match(source, /if \(changed\)[\s\S]*?showOverlay\(\)/);
    assert.match(source, /function showOverlay\(\)[\s\S]*?overlayOpen = true[\s\S]*?overlayTimer\.restart\(\)/);
    assert.match(source, /id:\s*overlayTimer[\s\S]*?interval:\s*1600[\s\S]*?overlayOpen = false/);

    assert.match(osd, /readonly property bool k4OwnsVolumeHud:\s*Config\.options\.bar\.variant === "k4"/);
    assert.match(osd, /function onVolumeChanged\(\)[\s\S]*?!Audio\.ready \|\| root\.k4OwnsVolumeHud[\s\S]*?currentIndicator = "volume"/);
    assert.match(osd, /function onMutedChanged\(\)[\s\S]*?!Audio\.ready \|\| root\.k4OwnsVolumeHud[\s\S]*?currentIndicator = "volume"/);
    assert.match(osd, /target:\s*MprisController\.activePlayer[\s\S]*?function onVolumeChanged\(\)[\s\S]*?if \(root\.k4OwnsVolumeHud\)[\s\S]*?return/);
    assert.match(osd, /onK4OwnsVolumeHudChanged:[\s\S]*?protectionMessage !== ""[\s\S]*?currentIndicator === "volume" \|\| currentIndicator === "playerVolume"[\s\S]*?osdTimeout\.stop\(\)/);
    assert.match(osd, /function onSinkProtectionTriggered\(reason\)[\s\S]*?root\.triggerOsd\(\)/);
    assert.match(osd, /target:\s*Brightness[\s\S]*?currentIndicator = "brightness"[\s\S]*?root\.triggerOsd\(\)/);
    assert.match(osd, /target:\s*Hyprsunset[\s\S]*?currentIndicator = "gamma"[\s\S]*?root\.triggerOsd\(\)/);
});

test("clock and workspace adapters delegate to existing ii and Hyprland state", () => {
    const clock = read("modules/ii/k4bar/K4Clock.qml");
    const workspaces = read("modules/ii/k4bar/K4Workspaces.qml");
    const idle = read("modules/ii/k4bar/K4IdlePill.qml");

    assert.match(clock, /readonly property date date:\s*DateTime\.clock\.date/);
    assert.match(clock, /Qt\.locale\(Translation\.languageCode\)/);
    assert.doesNotMatch(clock, /Timer\s*\{/);

    assert.match(workspaces, /Hyprland\.workspaces\.values\.slice\(\)/);
    assert.match(workspaces, /values\.sort\(\(a, b\) => a\.id - b\.id\)/);
    assert.match(workspaces, /readonly property int activeId:[\s\S]*?for \(let i = 0; i < list\.length; \+\+i\)[\s\S]*?if \(list\[i\]\.focused\)[\s\S]*?return list\[i\]\.id[\s\S]*?return -1/);
    assert.doesNotMatch(executableSource(workspaces), /Hyprland\.focusedWorkspace/);

    assert.match(idle, /Repeater\s*\{[\s\S]*?model:\s*3[\s\S]*?required property int index/);
    assert.match(idle, /readonly property var workspace:\s*index < root\.visibleWorkspaces\.length \? root\.visibleWorkspaces\[index\] : null/);
    assert.match(idle, /readonly property bool focused:\s*workspace !== null && workspace\.id === root\.activeWorkspaceId/);
    assert.doesNotMatch(idle, /model:\s*root\.visibleWorkspaces/);
    assert.match(idle, /Layout\.preferredWidth:\s*focused \? 18 : 6/);
});

test("core built-ins preserve k4 priorities, activation defaults and dimensions", () => {
    const source = read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(source, /name:\s*"volume"[\s\S]*?priority:\s*40[\s\S]*?active:\s*enabled && K4Audio\.overlayOpen[\s\S]*?islandWidth:\s*240[\s\S]*?islandHeight:\s*40/);
    assert.match(source, /name:\s*"clock"[\s\S]*?priority:\s*50[\s\S]*?active:\s*enabled && IslandState\.hovered[\s\S]*?islandHeight:\s*68/);

    assert.match(source, /property bool playerHoverSession:\s*false/);
    assert.match(source, /function onIsPlayingChanged\(\)[\s\S]*?IslandState\.hovered && K4Media\.isPlaying[\s\S]*?playerHoverSession = true/);
    assert.match(source, /function onHasPlayerChanged\(\)[\s\S]*?!K4Media\.hasPlayer[\s\S]*?playerHoverSession = false/);
    assert.match(source, /function onHoveredChanged\(\)[\s\S]*?!IslandState\.hovered[\s\S]*?playerHoverSession = false[\s\S]*?K4Media\.isPlaying[\s\S]*?playerHoverSession = true/);
    assert.match(source, /name:\s*"player"[\s\S]*?priority:\s*55[\s\S]*?closeOnDisable:\s*false[\s\S]*?active:\s*enabled[\s\S]*?IslandState\.hovered && root\.passiveHoverAllowed[\s\S]*?K4Media\.hasPlayer[\s\S]*?K4Media\.isPlaying \|\| root\.playerHoverSession[\s\S]*?trackPeekOpen[\s\S]*?islandWidth:\s*340[\s\S]*?K4Media\.hasTimeline \? 140 : 115/);

    assert.match(source, /view:\s*Component \{ K4VolumeView \{\} \}/);
    assert.match(source, /view:\s*Component \{ K4ClockView \{ trayPlugin: root\.trayPlugin \} \}/);
    assert.match(source, /view:\s*Component \{ K4PlayerView \{\} \}/);
});

test("core views preserve k4 volume, clock and player interaction contracts", () => {
    const theme = read("modules/ii/k4bar/K4Theme.qml");
    const volume = read("modules/ii/k4bar/K4VolumeView.qml");
    const clock = read("modules/ii/k4bar/K4ClockView.qml");
    const player = read("modules/ii/k4bar/K4PlayerView.qml");
    const recording = read("modules/ii/k4bar/K4RecordingPill.qml");

    assert.match(theme, /readonly property string iconFont:\s*"MesloLGS Nerd Font Mono"/);
    for (const glyph of ["play", "pause", "next", "prev", "shuffle", "output", "music", "volHigh", "volMed", "volOff"])
        assert.match(theme, new RegExp(`${glyph}:\\s*String\\.fromCodePoint`));

    assert.match(volume, /anchors\.leftMargin:\s*14[\s\S]*?anchors\.rightMargin:\s*14[\s\S]*?spacing:\s*10/);
    assert.match(volume, /K4Audio\.muted \? "—" : K4Audio\.volume \+ "%"/);
    assert.match(volume, /K4Audio\.volume \/ 100/);
    assert.match(volume, /NumberAnimation \{ duration:\s*140/);

    assert.match(clock, /anchors\.leftMargin:\s*22[\s\S]*?anchors\.rightMargin:\s*22/);
    assert.match(clock, /anchors\.horizontalCenter:\s*parent\.horizontalCenter[\s\S]*?Qt\.formatDateTime\(K4Clock\.date, "HH:mm"\)[\s\S]*?font\.pixelSize:\s*30/);
    assert.match(clock, /K4RecordingPill\s*\{[\s\S]*?interactive:\s*true/);

    assert.match(player, /Component\.onCompleted:[\s\S]*?K4Media\.watchPosition\(\)/);
    assert.match(player, /Component\.onDestruction:\s*K4Media\.unwatchPosition\(\)/);
    assert.match(player, /visible:\s*K4Media\.hasTimeline/);
    assert.match(player, /K4Media\.seekTo\(mouse\.x \/ width\)/);
    assert.match(player, /onActivated:\s*K4Media\.previous\(\)/);
    assert.match(player, /onActivated:\s*K4Media\.togglePlaying\(\)/);
    assert.match(player, /onActivated:\s*K4Media\.next\(\)/);
    assert.match(player, /K4RecordingPill\s*\{[\s\S]*?interactive:\s*true/);
    assert.match(player, /glyph:\s*K4Theme\.ico\.output[\s\S]*?enabledAction:\s*true[\s\S]*?onActivated:\s*K4Panel\.openTab\("sonido"\)/);

    assert.match(recording, /Persistent\.states\.screenRecord\.active/);
    assert.match(recording, /Persistent\.states\.screenRecord\.seconds/);
    assert.match(recording, /Quickshell\.execDetached\(Directories\.recordScriptPath\)/);
    assert.match(recording, /color:\s*K4Theme\.red/);
});
