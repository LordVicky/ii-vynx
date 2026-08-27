import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 layer surface only shrinks while the island is idle", async () => {
    const source = await read("modules/ii/k4bar/K4Bar.qml");

    assert.match(source,
        /onTargetHeightChanged:\s*\{[\s\S]*?surfaceShrinkTimer\.stop\(\)[\s\S]*?if \(targetHeight > surfaceHeight\)[\s\S]*?surfaceHeight = targetHeight[\s\S]*?else if \(showingIdle && !bottom\)[\s\S]*?surfaceShrinkTimer\.restart\(\)/);

    assert.match(source,
        /id:\s*surfaceShrinkTimer[\s\S]*?interval:\s*520[\s\S]*?onTriggered:\s*\{[\s\S]*?if \(panelWindow\.showingIdle && !panelWindow\.bottom\)[\s\S]*?panelWindow\.surfaceHeight = panelWindow\.targetHeight/);
});

test("K4 bottom placement retains surface capacity instead of resizing after collapse", async () => {
    const source = await read("modules/ii/k4bar/K4Bar.qml");

    assert.match(source,
        /onBottomChanged:\s*\{[\s\S]*?if \(!bottom && showingIdle\)[\s\S]*?surfaceHeight = targetHeight[\s\S]*?island\.publishRect\(\)/);
});
