import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

const panelSources = [
    "modules/ii/k4bar/K4PanelView.qml",
    "modules/ii/k4bar/K4PanelButton.qml",
    "modules/ii/k4bar/K4PanelConnectionRow.qml",
    "modules/ii/k4bar/K4PanelWifiView.qml",
    "modules/ii/k4bar/K4PanelBluetoothView.qml",
    "modules/ii/k4bar/K4PanelAudioView.qml",
    "modules/ii/k4bar/K4PanelNotificationsView.qml"
];

test("control center follows the K4 Qt Quick text rendering path", async () => {
    for (const path of panelSources) {
        const source = await read(path);
        assert.doesNotMatch(source, /renderType:\s*Text\.NativeRendering/);
    }

    const view = await read("modules/ii/k4bar/K4PanelView.qml");
    assert.match(view, /font\.family:\s*K4Theme\.uiFont/);
    assert.match(view, /font\.family:\s*K4Theme\.iconFont/);
});

test("sound device navigation and selection use full explicit hit targets", async () => {
    const view = await read("modules/ii/k4bar/K4PanelView.qml");
    const audio = await read("modules/ii/k4bar/K4PanelAudioView.qml");

    assert.match(view, /id:\s*soundDeviceButton[\s\S]*?TapHandler[\s\S]*?root\.plugin\.openTab\("sonido"\)/);
    assert.match(audio, /id:\s*deviceTap[\s\S]*?K4AudioDevices\.selectInput\(row\.modelData\)[\s\S]*?K4AudioDevices\.selectOutput\(row\.modelData\)/);
    assert.doesNotMatch(audio, /MouseArea\s*\{[\s\S]{0,100}?z:\s*-1[\s\S]{0,300}?selectOutput/);
});

test("now playing transport stays centered as expanded island width changes", async () => {
    const view = await read("modules/ii/k4bar/K4PanelView.qml");

    assert.match(view, /id:\s*mediaTransportZone[\s\S]*?id:\s*mediaTransport[\s\S]*?anchors\.horizontalCenter:\s*parent\.horizontalCenter/);
});

test("control center surfaces use the OLED-black K4 palette", async () => {
    const theme = await read("modules/ii/k4bar/K4Theme.qml");

    assert.match(theme, /panelSurface:\s*"#050505"/);
    assert.match(theme, /panelSurfaceHi:\s*"#111113"/);
    assert.match(theme, /panelSurfaceHot:\s*"#1a1a1d"/);
    assert.match(theme, /panelTrack:\s*"#2a2a2e"/);
});
