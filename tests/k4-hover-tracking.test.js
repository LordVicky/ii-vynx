import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("scrolling connection rows derive hover from a stationary viewport MouseArea", async () => {
    const tracker = await read("modules/ii/k4bar/K4CursorTrackedListView.qml");

    assert.match(tracker, /property real trackedPointerY:\s*-1/);
    assert.match(tracker, /trackedPointerY\s*\+\s*contentY\s*-\s*originY/);
    assert.match(tracker, /Math\.floor\(relativeY\s*\/\s*rowStride\)/);
    assert.match(tracker, /offsetInRow\s*>=\s*0\s*&&\s*offsetInRow\s*<\s*rowHeight/);
    assert.doesNotMatch(tracker, /indexAt\s*\(/);

    assert.match(tracker, /MouseArea\s*\{[\s\S]*?id:\s*viewportMouse[\s\S]*?parent:\s*root[\s\S]*?anchors\.fill:\s*root/);
    assert.match(tracker, /hoverEnabled:\s*true/);
    assert.match(tracker, /acceptedButtons:\s*Qt\.NoButton/);
    assert.match(tracker, /scrollGestureEnabled:\s*false/);
    assert.match(tracker, /onEntered:\s*root\.trackedPointerY\s*=\s*mouseY/);
    assert.match(tracker, /onPositionChanged:\s*mouse\s*=>\s*root\.trackedPointerY\s*=\s*mouse\.y/);
    assert.match(tracker, /onExited:\s*root\.trackedPointerY\s*=\s*-1/);
    assert.match(tracker, /onWheel:\s*wheel\s*=>\s*wheel\.accepted\s*=\s*false/);
    assert.doesNotMatch(tracker, /HoverHandler|WheelHandler|\[K4Hover\]|console\.warn/);
});

test("connection rows render externally-derived hover with visible contrast", async () => {
    const row = await read("modules/ii/k4bar/K4PanelConnectionRow.qml");

    assert.match(row, /property bool hovered:\s*false/);
    assert.match(row, /root\.hovered\s*\?\s*K4Theme\.surfaceHi\s*:\s*"transparent"/);
    assert.doesNotMatch(row, /root\.hovered\s*\?\s*K4Theme\.surface\s*:/);
    assert.doesNotMatch(row, /containsMouse|HoverHandler|hoverEnabled|reportPointer|rememberPointer/);
    assert.doesNotMatch(row, /Behavior\s+on\s+color/);
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

test("launcher reuses the validated viewport list tracker without animated hover", async () => {
    const launcher = await read("modules/ii/k4bar/K4LauncherView.qml");

    assert.match(launcher, /K4CursorTrackedListView\s*\{[\s\S]*?id:\s*appResults[\s\S]*?rowHeight:\s*42/);
    assert.match(launcher, /onHoveredIndexChanged:[\s\S]*?root\.plugin\.index\s*=\s*hoveredIndex/);
    assert.match(launcher, /readonly property bool hovered:\s*index\s*===\s*appResults\.hoveredIndex/);
    assert.match(launcher, /readonly property bool highlighted:[\s\S]*?appResults\.trackedPointerY\s*<\s*0/);
    assert.match(launcher, /color:\s*highlighted\s*\?\s*K4Theme\.surfaceHi\s*:\s*"transparent"/);
    assert.match(launcher, /height:\s*ListView\.view\.rowHeight/);
    assert.doesNotMatch(launcher, /Behavior\s+on\s+color|highlightMoveDuration/);
    assert.doesNotMatch(launcher, /hoverEnabled:\s*true[\s\S]*?onEntered:\s*root\.plugin\.index/);
});

test("sound rows use immediate visible hover contrast", async () => {
    const sound = await read("modules/ii/k4bar/K4PanelAudioView.qml");

    assert.match(sound, /color:\s*selected\s*\?\s*K4Theme\.surfaceHi\s*:\s*rowHover\.hovered\s*\?\s*K4Theme\.surfaceHi\s*:\s*"transparent"/);
    assert.match(sound, /HoverHandler\s*\{\s*id:\s*rowHover\s*\}/);
    assert.doesNotMatch(sound, /rowHover\.hovered\s*\?\s*K4Theme\.surface\s*:/);
    assert.doesNotMatch(sound, /Behavior\s+on\s+color/);
});
