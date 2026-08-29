import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("apps grid keeps viewport hover tracking inside the GridView root", async () => {
    const tracker = await read("modules/ii/k4bar/K4CursorTrackedGridView.qml");
    const apps = await read("modules/ii/k4bar/K4AppsView.qml");

    assert.match(tracker, /^GridView\s*\{/m);
    assert.match(tracker, /property real trackedPointerX:\s*-1/);
    assert.match(tracker, /property real trackedPointerY:\s*-1/);
    assert.match(tracker, /trackedPointerX\s*\+\s*contentX\s*-\s*originX/);
    assert.match(tracker, /trackedPointerY\s*\+\s*contentY\s*-\s*originY/);
    assert.match(tracker, /MouseArea\s*\{[\s\S]*?parent:\s*root[\s\S]*?anchors\.fill:\s*root/);
    assert.match(tracker, /acceptedButtons:\s*Qt\.NoButton/);
    assert.match(tracker, /onWheel:\s*wheel\s*=>\s*wheel\.accepted\s*=\s*false/);
    assert.doesNotMatch(tracker, /required property var surface|K4ViewportPointer/);

    assert.match(apps, /K4CursorTrackedGridView\s*\{[\s\S]*?id:\s*utilityGrid/);
    assert.match(apps, /hoverWidth:\s*cellWidth\s*-\s*6/);
    assert.match(apps, /hoverHeight:\s*cellHeight\s*-\s*6/);
    assert.doesNotMatch(apps, /onHoveredIndexChanged/);
    assert.match(apps, /readonly property bool hovered:\s*index\s*===\s*utilityGrid\.hoveredIndex/);
    assert.match(apps, /readonly property bool selected:\s*utilityGrid\.hoveredIndex\s*<\s*0[\s\S]*?index\s*===\s*root\.plugin\.selection/);
    assert.match(apps, /color:\s*hovered\s*\|\|\s*selected\s*\?\s*K4Theme\.surfaceHi/);
    assert.doesNotMatch(apps, /utilityMouse\.containsMouse|hoverEnabled:\s*true[\s\S]*?onEntered:\s*root\.plugin\.selection/);
    assert.doesNotMatch(apps, /Behavior\s+on\s+color/);
});
