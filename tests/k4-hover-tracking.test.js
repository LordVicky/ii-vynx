import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("connection rows use the same delegate-local MouseArea hover seam as Applications", async () => {
    const apps = await read("modules/ii/k4bar/K4AppsView.qml");
    const row = await read("modules/ii/k4bar/K4PanelConnectionRow.qml");

    assert.match(apps, /MouseArea\s*\{[\s\S]*?hoverEnabled:\s*true[\s\S]*?containsMouse/);
    assert.match(row, /MouseArea\s*\{[\s\S]*?id:\s*rowMouse[\s\S]*?hoverEnabled:\s*true/);
    assert.match(row, /rowMouse\.containsMouse\s*\?\s*K4Theme\.surface\s*:\s*"transparent"/);
    assert.doesNotMatch(row, /HoverHandler/);
});

test("Wi-Fi and Bluetooth use ordinary ListViews without viewport hover indirection", async () => {
    const wifi = await read("modules/ii/k4bar/K4PanelWifiView.qml");
    const bluetooth = await read("modules/ii/k4bar/K4PanelBluetoothView.qml");

    assert.match(wifi, /ListView\s*\{[\s\S]*?id:\s*networksList/);
    assert.doesNotMatch(wifi, /K4HoverListView|hoveredIndex|hovered:\s*index/);

    assert.match(bluetooth, /ListView\s*\{[\s\S]*?id:\s*devicesList/);
    assert.doesNotMatch(bluetooth, /K4HoverListView|hoveredIndex|hovered:\s*index/);
});
