import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 space mode is persisted and Settings exposes all approved choices", async () => {
    const config = await read("modules/common/Config.qml");
    const settings = await read("modules/ii/k4bar/K4Settings.qml");
    const view = await read("modules/ii/k4bar/K4SettingsView.qml");

    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property string spaceMode:\s*"reserve"/);

    assert.match(settings, /readonly property string spaceMode:\s*Config\.options\.bar\.k4\.spaceMode/);
    assert.match(settings, /readonly property var spaceModes:[\s\S]*?"Reserve space"[\s\S]*?value:\s*"reserve"[\s\S]*?"Away when fullscreen"[\s\S]*?value:\s*"fullscreen"[\s\S]*?"On top"[\s\S]*?value:\s*"overlay"[\s\S]*?"Hidden"[\s\S]*?value:\s*"hidden"/);
    assert.match(settings, /function setSpaceMode\(wanted\)[\s\S]*?\["reserve", "fullscreen", "overlay", "hidden"\]\.indexOf\(value\) >= 0[\s\S]*?Config\.options\.bar\.k4\.spaceMode = value/);

    assert.match(view, /K4Settings\.spaceModes/);
    assert.match(view, /K4Settings\.spaceMode/);
    assert.match(view, /K4Settings\.setSpaceMode\(/);
    assert.match(view, /Away when fullscreen|Hidden/);
});

test("K4 fullscreen query reuses HyprlandData monitor and workspace snapshots", async () => {
    const hyprland = await read("services/HyprlandData.qml");

    assert.match(hyprland, /function monitorHasFullscreen\(screenName\)[\s\S]*?root\.monitors/);
    assert.match(hyprland, /function monitorHasFullscreen\(screenName\)[\s\S]*?activeWorkspace[\s\S]*?root\.workspaceById/);
    assert.match(hyprland, /function monitorHasFullscreen\(screenName\)[\s\S]*?hasfullscreen/);
    assert.match(hyprland, /onRawEvent\(event\)[\s\S]*?fullscreen[\s\S]*?closewindow[\s\S]*?updateWorkspaces\(\)/);

    const k4Bar = await read("modules/ii/k4bar/K4Bar.qml");
    assert.doesNotMatch(k4Bar, /command:\s*\[\s*"hyprctl"[\s\S]*?(workspaces|monitors)/);
});

test("K4 host resolves Away-when-fullscreen per monitor and only Reserve claims space", async () => {
    const source = await read("modules/ii/k4bar/K4Bar.qml");

    assert.match(source, /import qs\.services/);
    assert.match(source, /readonly property string effectiveSpaceMode:[\s\S]*?K4Settings\.spaceMode === "fullscreen"[\s\S]*?HyprlandData\.monitorHasFullscreen\(panelWindow\.screen\.name\)[\s\S]*?\? "hidden" : "reserve"/);
    assert.match(source, /readonly property bool hideMode:\s*effectiveSpaceMode === "hidden"/);
    assert.match(source, /exclusiveZone:\s*panelWindow\.effectiveSpaceMode === "reserve"\s*\?\s*K4Theme\.baseHeight\s*:\s*0/);
    assert.match(source, /notificationOverlay:[\s\S]*?effectiveSpaceMode === "hidden"/);
});

test("K4 Hidden withdraws only the island drawing and keeps a narrow reveal strip", async () => {
    const source = await read("modules/ii/k4bar/K4Bar.qml");

    assert.match(source, /property bool withdrawn:\s*false/);
    assert.match(source, /function reconsiderWithdrawal\(\)[\s\S]*?withdrawTimer\.stop\(\)[\s\S]*?withdrawn = false[\s\S]*?withdrawTimer\.restart\(\)/);
    assert.match(source, /id:\s*withdrawTimer[\s\S]*?interval:\s*1600[\s\S]*?panelWindow\.withdrawn = panelWindow\.hideMode[\s\S]*?!panelWindow\.shouldShow/);

    assert.match(source, /id:\s*revealEdge[\s\S]*?x:\s*island\.x[\s\S]*?width:\s*island\.width[\s\S]*?height:\s*4[\s\S]*?opacity:\s*0/);
    assert.match(source, /mask:\s*Region\s*\{[\s\S]*?item:\s*IslandState\.suppressed \? null : island[\s\S]*?item:\s*\(IslandState\.suppressed \|\| !panelWindow\.hideMode\) \? null : revealEdge[\s\S]*?Intersection\.Combine/);

    assert.match(source, /id:\s*withdrawTranslate[\s\S]*?panelWindow\.withdrawn[\s\S]*?panelWindow\.bottom \? island\.height \+ 6[\s\S]*?: -\(island\.height \+ 6\)[\s\S]*?duration:\s*360[\s\S]*?Easing\.OutCubic/);
    assert.match(source, /id:\s*hoverDwellTimer[\s\S]*?interval:\s*500[\s\S]*?controller\.hoverEntered\(panelWindow\.screen\.name\)/);

    // Hidden must not add a full-edge catcher or resize the layer surface per frame.
    assert.doesNotMatch(source, /revealEdge[\s\S]*?width:\s*parent\.width/);
    assert.doesNotMatch(source, /onWithdrawnChanged:[\s\S]*?surfaceHeight\s*=/);
});
