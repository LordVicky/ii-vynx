import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("control center home keeps readable K4 body type instead of sub-10px labels", async () => {
    const view = await read("modules/ii/k4bar/K4PanelView.qml");

    assert.doesNotMatch(view, /font\.pixelSize:\s*[1-9]\b/);
    assert.match(view, /text:\s*"Wi-Fi"[\s\S]*?font\.pixelSize:\s*12/);
    assert.match(view, /component\s+ToolTile:[\s\S]*?font\.pixelSize:\s*10/);
    assert.match(view, /component\s+DesktopTile:[\s\S]*?font\.pixelSize:\s*11[\s\S]*?font\.pixelSize:\s*10/);
    assert.match(view, /text:\s*"NOW PLAYING"[\s\S]*?font\.pixelSize:\s*10/);
});

test("now playing card derives its surface from the current album artwork", async () => {
    const view = await read("modules/ii/k4bar/K4PanelView.qml");

    assert.match(view, /import\s+Quickshell\.Widgets/);
    assert.match(view, /id:\s*mediaCard[\s\S]*?color:\s*"transparent"/);
    assert.match(view, /ClippingRectangle\s*\{[\s\S]*?id:\s*mediaBackdrop[\s\S]*?source:\s*K4Media\.coverFor\(K4Media\.activePlayer\)/);
    assert.match(view, /visible:\s*K4Media\.hasPlayer\s*&&\s*status\s*===\s*Image\.Ready/);
    assert.match(view, /opacity:\s*0\.38/);
});
