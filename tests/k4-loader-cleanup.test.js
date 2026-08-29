import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 plugin view loader has no removed lifecycle error bookkeeping", async () => {
    const source = await read("modules/ii/k4bar/K4Bar.qml");

    assert.doesNotMatch(source, /loadError/);
    assert.match(source, /delegate:\s*Loader\s*\{[\s\S]*?active:\s*modelData\?\.name\s*!==\s*"idle"/);
    assert.match(source, /sourceComponent:\s*modelData\?\.view\s*\?\?\s*null/);
});
