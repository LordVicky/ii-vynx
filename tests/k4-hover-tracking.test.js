import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("shared viewport pointer tracks a stationary cursor without owning clicks or wheel", async () => {
    const pointer = await read("modules/ii/k4bar/K4ViewportPointer.qml");

    assert.match(pointer, /required property var surface/);
    assert.match(pointer, /property real pointerX:\s*-1/);
    assert.match(pointer, /property real pointerY:\s*-1/);
    assert.match(pointer, /surface\.contentX\s*\+\s*surface\.contentY/);
    assert.match(pointer, /item\.mapFromItem\(surface, pointerX, pointerY\)/);
    assert.match(pointer, /point\.x\s*>=\s*0[\s\S]*?point\.y\s*>=\s*0/);
    assert.match(pointer, /MouseArea\s*\{[\s\S]*?parent:\s*root\.surface[\s\S]*?anchors\.fill:\s*root\.surface/);
    assert.match(pointer, /hoverEnabled:\s*true/);
    assert.match(pointer, /acceptedButtons:\s*Qt\.NoButton/);
    assert.match(pointer, /scrollGestureEnabled:\s*false/);
    assert.match(pointer, /onPositionChanged:\s*mouse\s*=>[\s\S]*?root\.pointerY\s*=\s*mouse\.y/);
    assert.match(pointer, /onWheel:\s*wheel\s*=>\s*wheel\.accepted\s*=\s*false/);
});

test("fixed connection lists compose the shared viewport pointer and preserve row math", async () => {
    const tracker = await read("modules/ii/k4bar/K4CursorTrackedListView.qml");
    const wifi = await read("modules/ii/k4bar/K4PanelWifiView.qml");
    const bluetooth = await read("modules/ii/k4bar/K4PanelBluetoothView.qml");

    assert.match(tracker, /readonly property real trackedPointerY:\s*viewportPointer\.pointerY/);
    assert.match(tracker, /trackedPointerY\s*\+\s*contentY\s*-\s*originY/);
    assert.match(tracker, /Math\.floor\(relativeY\s*\/\s*rowStride\)/);
    assert.match(tracker, /offsetInRow\s*>=\s*0\s*&&\s*offsetInRow\s*<\s*rowHeight/);
    assert.match(tracker, /K4ViewportPointer\s*\{[\s\S]*?surface:\s*root/);
    assert.doesNotMatch(tracker, /MouseArea|HoverHandler|WheelHandler|indexAt\s*\(/);

    assert.match(wifi, /K4CursorTrackedListView\s*\{[\s\S]*?id:\s*networksList[\s\S]*?rowHeight:\s*42/);
    assert.match(wifi, /hovered:\s*index\s*===\s*networksList\.hoveredIndex/);
    assert.match(bluetooth, /K4CursorTrackedListView\s*\{[\s\S]*?id:\s*devicesList[\s\S]*?rowHeight:\s*42/);
    assert.match(bluetooth, /hovered:\s*index\s*===\s*devicesList\.hoveredIndex/);
});

test("connection rows render tracked hover with visible contrast", async () => {
    const row = await read("modules/ii/k4bar/K4PanelConnectionRow.qml");

    assert.match(row, /property bool hovered:\s*false/);
    assert.match(row, /root\.hovered\s*\?\s*K4Theme\.surfaceHi\s*:\s*"transparent"/);
    assert.doesNotMatch(row, /root\.hovered\s*\?\s*K4Theme\.surface\s*:/);
    assert.doesNotMatch(row, /Behavior\s+on\s+color/);
});

test("selection-driven scroll surfaces derive selection hover from viewport geometry", async () => {
    const apps = await read("modules/ii/k4bar/K4AppsView.qml");
    const launcher = await read("modules/ii/k4bar/K4LauncherView.qml");
    const clipboard = await read("modules/ii/k4bar/K4ClipboardView.qml");
    const files = await read("modules/ii/k4bar/K4FilesView.qml");

    for (const source of [apps, launcher, clipboard, files]) {
        assert.match(source, /K4ViewportPointer\s*\{/);
        assert.match(source, /readonly property bool hovered:\s*\w+Pointer\.contains\(/);
        assert.match(source, /onHoveredChanged:[\s\S]*?if \(hovered\)/);
    }

    assert.doesNotMatch(apps, /utilityMouse\.containsMouse|Behavior\s+on\s+color/);
    assert.doesNotMatch(launcher, /hoverEnabled:\s*true[\s\S]*?onEntered:\s*root\.plugin\.index|Behavior\s+on\s+color/);
    assert.doesNotMatch(clipboard, /rowMouse\.containsMouse|Behavior\s+on\s+color/);
    assert.doesNotMatch(files, /rowMouse\.containsMouse/);
});

test("all remaining interactive scroll surfaces use viewport-derived hover", async () => {
    const audio = await read("modules/ii/k4bar/K4PanelAudioView.qml");
    const keys = await read("modules/ii/k4bar/K4KeysView.qml");
    const notifications = await read("modules/ii/k4bar/K4PanelNotificationsView.qml");
    const tray = await read("modules/ii/k4bar/K4TrayView.qml");
    const displays = await read("modules/ii/k4bar/K4DisplaysView.qml");
    const settings = await read("modules/ii/k4bar/K4SettingsView.qml");
    const settingsToggle = await read("modules/ii/k4bar/K4SettingsToggle.qml");
    const weather = await read("modules/ii/k4bar/K4WeatherView.qml");

    for (const source of [audio, keys, notifications, tray, displays, settings, weather])
        assert.match(source, /K4ViewportPointer\s*\{/);

    assert.match(audio, /hoverTracker\.contains\(row\)/);
    assert.doesNotMatch(audio, /rowHover\.hovered|Behavior\s+on\s+color/);

    assert.match(keys, /keysPointer\.contains\(keySurface\)/);
    assert.doesNotMatch(keys, /hover\.containsMouse|Behavior\s+on\s+color/);

    assert.match(notifications, /notificationsPointer\.contains\(card\)/);
    assert.match(notifications, /notificationsPointer\.contains\(chip\)/);
    assert.doesNotMatch(notifications, /cardHover\.hovered|chipHover\.hovered|Behavior\s+on\s+color/);

    assert.match(tray, /trayAppsPointer\.contains\(appRow\)/);
    assert.match(tray, /trayMenuPointer\.contains\(entryRow\)/);
    assert.doesNotMatch(tray, /appMouse\.containsMouse|entryMouse\.containsMouse|Behavior\s+on\s+color/);

    assert.match(displays, /monitorPointer\.contains\(monitorRow\)/);
    assert.match(displays, /modePointer\.contains\(modeChip\)/);
    assert.doesNotMatch(displays, /monitorMouse\.containsMouse/);

    assert.match(settings, /settingsPointer\.contains\(positionChoice\)/);
    assert.match(settings, /settingsPointer\.contains\(alignmentChoice\)/);
    assert.match(settings, /settingsPointer\.contains\(spaceChoice\)/);
    assert.match(settings, /externalHovered:\s*settingsPointer\.contains\(/);
    assert.match(settingsToggle, /property bool externalHovered:\s*false/);
    assert.match(settingsToggle, /externalHovered\s*\|\|\s*rowHover\.hovered\s*\?\s*K4Theme\.surfaceHi/);

    assert.match(weather, /cityPointer\.contains\(cityRow\)/);
    assert.doesNotMatch(weather, /cityHover\.containsMouse/);
});
