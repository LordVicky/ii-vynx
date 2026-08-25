import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 space mode is persisted and Settings exposes only implemented choices", async () => {
    const config = await read("modules/common/Config.qml");
    const settings = await read("modules/ii/k4bar/K4Settings.qml");
    const view = await read("modules/ii/k4bar/K4SettingsView.qml");

    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property string spaceMode:\s*"reserve"/);

    assert.match(settings, /readonly property string spaceMode:\s*Config\.options\.bar\.k4\.spaceMode/);
    assert.match(settings, /readonly property var spaceModes:[\s\S]*?"Reserve space"[\s\S]*?value:\s*"reserve"[\s\S]*?"On top"[\s\S]*?value:\s*"overlay"/);
    assert.doesNotMatch(settings, /spaceModes:[\s\S]*?value:\s*"hidden"/);
    assert.doesNotMatch(settings, /spaceModes:[\s\S]*?value:\s*"fullscreen"/);
    assert.match(settings, /function setSpaceMode\(wanted\)[\s\S]*?value === "reserve" \|\| value === "overlay"[\s\S]*?Config\.options\.bar\.k4\.spaceMode = value/);

    assert.match(view, /K4Settings\.spaceModes/);
    assert.match(view, /K4Settings\.spaceMode/);
    assert.match(view, /K4Settings\.setSpaceMode\(/);
});

test("K4 fullscreen query reuses HyprlandData monitor and workspace snapshots", async () => {
    const hyprland = await read("services/HyprlandData.qml");

    assert.match(hyprland, /function monitorHasFullscreen\(screenName\)[\s\S]*?root\.monitors/);
    assert.match(hyprland, /function monitorHasFullscreen\(screenName\)[\s\S]*?activeWorkspace[\s\S]*?root\.workspaceById/);
    assert.match(hyprland, /function monitorHasFullscreen\(screenName\)[\s\S]*?hasfullscreen/);
    assert.match(hyprland, /onRawEvent\(event\)[\s\S]*?fullscreen[\s\S]*?closewindow[\s\S]*?updateWorkspaces\(\)/);

    // The approved seam belongs to the existing HyprlandData singleton; K4
    // must not introduce a second fullscreen poller/service in its module.
    const k4Bar = await read("modules/ii/k4bar/K4Bar.qml");
    assert.doesNotMatch(k4Bar, /command:\s*\[\s*"hyprctl"[\s\S]*?(workspaces|monitors)/);
});

test("K4 host resolves per-screen space mode and only Reserve claims exclusive zone", async () => {
    const source = await read("modules/ii/k4bar/K4Bar.qml");

    assert.match(source, /readonly property string effectiveSpaceMode:\s*K4Settings\.spaceMode/);
    assert.match(source, /exclusiveZone:\s*panelWindow\.effectiveSpaceMode === "reserve"\s*\?\s*K4Theme\.baseHeight\s*:\s*0/);
    assert.doesNotMatch(source, /id:\s*revealEdge|property bool withdrawn|withdrawTimer/);
});
