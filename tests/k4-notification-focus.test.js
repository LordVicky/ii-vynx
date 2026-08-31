import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 notification focus resolves both Quickshell toplevel shapes", async () => {
    const notifications = await read("modules/ii/k4bar/K4Notifications.qml");

    assert.match(notifications, /function clientForFocusedToplevel\(toplevel\)/);
    assert.match(notifications, /HyprlandData\.clientForToplevel\(toplevel\)/);
    assert.match(notifications, /toplevel\?\.address/);
    assert.match(notifications, /HyprlandData\.windowByAddress\[address\]/);
    assert.match(notifications, /function belongsToToplevel\(notification, toplevel\)[\s\S]*?clientForFocusedToplevel\(toplevel\)/);
});
