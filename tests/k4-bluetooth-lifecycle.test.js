import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 stops Bluetooth discovery only when K4 started it", async () => {
    const source = await read("modules/ii/k4bar/K4Bluetooth.qml");

    assert.match(source, /property bool ownsDiscovery:\s*false/);
    assert.match(source, /property var discoveryAdapter:\s*null/);
    assert.match(source,
        /if \(target\)[\s\S]*?if \(!current \|\| !current\.enabled \|\| ownsDiscovery\)[\s\S]*?if \(current\.discovering === target\)[\s\S]*?return[\s\S]*?ownsDiscovery = true[\s\S]*?discoveryAdapter = current[\s\S]*?current\.discovering = target/);
    assert.match(source,
        /if \(!ownsDiscovery\)\s*return[\s\S]*?const owner = discoveryAdapter[\s\S]*?ownsDiscovery = false[\s\S]*?discoveryAdapter = null[\s\S]*?owner\.discovering = target/);
});
