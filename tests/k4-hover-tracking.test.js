import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("scrolling connection rows update hover styling without a trailing color animation", async () => {
    const row = await read("modules/ii/k4bar/K4PanelConnectionRow.qml");

    assert.match(row, /hover\.hovered\s*\?\s*K4Theme\.surface\s*:\s*"transparent"/);
    assert.doesNotMatch(row, /Behavior\s+on\s+color/);
});
