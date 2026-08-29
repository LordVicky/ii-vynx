import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("scrolling connection rows derive hover from a stationary viewport pointer", async () => {
    const tracker = await read("modules/ii/k4bar/K4CursorTrackedListView.qml");

    assert.match(tracker, /property real trackedPointerY:\s*-1/);
    assert.match(tracker, /trackedPointerY\s*\+\s*contentY\s*-\s*originY/);
    assert.match(tracker, /Math\.floor\(relativeY\s*\/\s*rowStride\)/);
    assert.doesNotMatch(tracker, /indexAt\s*\(/);

    assert.match(tracker, /HoverHandler\s*\{[\s\S]*?blocking:\s*false[\s\S]*?onHoveredChanged/);
    assert.doesNotMatch(tracker, /onPointChanged/);
    assert.match(tracker, /WheelHandler\s*\{[\s\S]*?target:\s*null[\s\S]*?blocking:\s*false/);
    assert.match(tracker, /acceptedDevices:\s*PointerDevice\.Mouse\s*\|\s*PointerDevice\.TouchPad/);
    assert.match(tracker, /onWheel:\s*event\s*=>\s*root\.rememberPointer\(event\.y\)/);
});

test("connection rows feed normal cursor movement into viewport hover tracking", async () => {
    const row = await read("modules/ii/k4bar/K4PanelConnectionRow.qml");

    assert.match(row, /property bool hovered:\s*false/);
    assert.match(row, /root\.hovered\s*\?\s*K4Theme\.surface\s*:\s*"transparent"/);
    assert.match(row, /const tracker = root\.ListView\.view/);
    assert.match(row, /rowMouse\.mapToItem\(tracker, x, y\)/);
    assert.match(row, /tracker\.rememberPointer\(mapped\.y\)/);
    assert.match(row, /MouseArea\s*\{[\s\S]*?id:\s*rowMouse[\s\S]*?hoverEnabled:\s*true/);
    assert.match(row, /onEntered:\s*root\.reportPointer\(mouseX, mouseY\)/);
    assert.match(row, /onPositionChanged:\s*mouse\s*=>\s*root\.reportPointer\(mouse\.x, mouse\.y\)/);
    assert.doesNotMatch(row, /containsMouse|HoverHandler|Behavior\s+on\s+color/);
});

test("Wi-Fi and Bluetooth bind fixed-height rows to viewport-derived hover indices", async () => {
    const wifi = await read("modules/ii/k4bar/K4PanelWifiView.qml");
    const bluetooth = await read("modules/ii/k4bar/K4PanelBluetoothView.qml");

    assert.match(wifi, /K4CursorTrackedListView\s*\{[\s\S]*?id:\s*networksList[\s\S]*?rowHeight:\s*42/);
    assert.match(wifi, /required property int index/);
    assert.match(wifi, /height:\s*ListView\.view\.rowHeight/);
    assert.match(wifi, /hovered:\s*index\s*===\s*networksList\.hoveredIndex/);

    assert.match(bluetooth, /K4CursorTrackedListView\s*\{[\s\S]*?id:\s*devicesList[\s\S]*?rowHeight:\s*42/);
    assert.match(bluetooth, /required property int index/);
    assert.match(bluetooth, /height:\s*ListView\.view\.rowHeight/);
    assert.match(bluetooth, /hovered:\s*index\s*===\s*devicesList\.hoveredIndex/);
});
