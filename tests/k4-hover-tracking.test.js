import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("scrolling lists derive hover from viewport position plus content offset", async () => {
    const list = await read("modules/ii/k4bar/K4HoverListView.qml");

    assert.match(list, /readonly property int hoveredIndex:/);
    assert.match(list, /indexAt\([\s\S]*?point\.position\.x\s*\+\s*root\.contentX[\s\S]*?point\.position\.y\s*\+\s*root\.contentY/);
    assert.match(list, /HoverHandler\s*\{[\s\S]*?blocking:\s*false/);
});

test("connection rows render externally-derived hover without delegate-local tracking", async () => {
    const row = await read("modules/ii/k4bar/K4PanelConnectionRow.qml");

    assert.match(row, /property bool hovered:\s*false/);
    assert.match(row, /root\.hovered\s*\?\s*K4Theme\.surface\s*:\s*"transparent"/);
    assert.doesNotMatch(row, /HoverHandler/);
    assert.doesNotMatch(row, /Behavior\s+on\s+color/);
});

test("Wi-Fi and Bluetooth connection rows use viewport-derived hover indices", async () => {
    const wifi = await read("modules/ii/k4bar/K4PanelWifiView.qml");
    const bluetooth = await read("modules/ii/k4bar/K4PanelBluetoothView.qml");

    assert.match(wifi, /K4HoverListView\s*\{[\s\S]*?id:\s*networksList/);
    assert.match(wifi, /required property int index/);
    assert.match(wifi, /hovered:\s*index\s*===\s*networksList\.hoveredIndex/);

    assert.match(bluetooth, /K4HoverListView\s*\{[\s\S]*?id:\s*devicesList/);
    assert.match(bluetooth, /required property int index/);
    assert.match(bluetooth, /hovered:\s*index\s*===\s*devicesList\.hoveredIndex/);
});
