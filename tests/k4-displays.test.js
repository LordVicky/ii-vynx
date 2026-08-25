import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 Displays reuses HyprlandData and applies session-only monitor drafts", async () => {
    const plugin = await read("modules/ii/k4bar/K4DisplaysPlugin.qml");
    const view = await read("modules/ii/k4bar/K4DisplaysView.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const hyprlandData = await read("services/HyprlandData.qml");

    assert.match(plugin, /name:\s*"displays"/);
    assert.match(plugin, /priority:\s*67/);
    assert.match(plugin, /application:\s*true/);
    assert.match(plugin, /active:\s*enabled\s*&&\s*open/);
    assert.match(plugin, /HyprlandData\.monitors/);
    assert.match(plugin, /HyprlandData\.updateMonitors\(\)/);

    assert.match(plugin, /function rebuildDrafts\(\)/);
    assert.match(plugin, /function updateSelected\(key, value\)/);
    assert.match(plugin, /function placeSelected\(where\)/);
    assert.match(plugin, /function apply\(\)/);
    assert.match(plugin, /\["hyprctl",\s*"eval"/);
    assert.match(plugin, /hl\.monitor\(\{/);
    assert.match(plugin, /mode\s*=\s*/);
    assert.match(plugin, /position\s*=\s*/);
    assert.match(plugin, /scale\s*=\s*/);
    assert.match(plugin, /transform\s*=\s*/);

    assert.doesNotMatch(plugin, /hyprctl["']?,\s*["']monitors/);
    assert.doesNotMatch(plugin, /python3|pantallas\.py|k4-displays|hyprland\.lua|FileView|setText\(/i);

    assert.match(view, /Displays/);
    assert.match(view, /Mode/);
    assert.match(view, /Scale/);
    assert.match(view, /Rotation/);
    assert.match(view, /Position/);
    assert.match(view, /Left/);
    assert.match(view, /Right/);
    assert.match(view, /Above/);
    assert.match(view, /Below/);
    assert.match(view, /Mirror/);
    assert.match(view, /Apply/);
    assert.match(view, /Refresh/);

    assert.match(builtins, /displaysPlugin/);
    assert.match(builtins, /property QtObject displaysPlugin:\s*K4DisplaysPlugin\s*\{\}/);

    assert.match(hyprlandData, /property var monitors:\s*\[\]/);
    assert.match(hyprlandData, /function updateMonitors\(\)/);
    assert.match(hyprlandData, /command:\s*\["hyprctl",\s*"monitors",\s*"-j"\]/);
});
