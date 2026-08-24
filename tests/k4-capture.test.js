import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 Capture is a thin application over existing ii capture owners", async () => {
    const plugin = await read("modules/ii/k4bar/K4CapturePlugin.qml");
    const view = await read("modules/ii/k4bar/K4CaptureView.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const region = await read("modules/ii/regionSelector/RegionSelector.qml");
    const recorder = await read("modules/ii/overlay/recorder/Recorder.qml");
    const recordScript = await read("scripts/videos/record.sh");

    assert.match(plugin, /name:\s*"capture"/);
    assert.match(plugin, /priority:\s*84/);
    assert.match(plugin, /application:\s*true/);
    assert.match(plugin, /applicationGlyph:/);
    assert.match(plugin, /active:\s*enabled\s*&&\s*open/);
    assert.match(plugin, /Persistent\.states\.screenRecord\.active/);
    assert.match(plugin, /Persistent\.states\.screenRecord\.seconds/);

    assert.match(plugin, /function regionCommand\(action\)[\s\S]*?"ipc",\s*"call",\s*"region",\s*action/);
    assert.match(plugin, /function screenshotRegion\(\)[\s\S]*?regionCommand\("screenshot"\)/);
    assert.match(plugin, /function recordRegion\(\)[\s\S]*?regionCommand\("recordWithSound"\)/);
    assert.match(plugin, /function recordScreen\(\)[\s\S]*?Directories\.recordScriptPath[\s\S]*?"--fullscreen"[\s\S]*?"--sound"/);
    assert.match(plugin, /function stopRecording\(\)[\s\S]*?Directories\.recordScriptPath/);
    assert.match(plugin, /function screenshotScreen\(\)[\s\S]*?grim - \| wl-copy/);

    assert.match(plugin, /IslandState\.hidden = true/);
    assert.match(plugin, /function releaseSuppression\(\)[\s\S]*?IslandState\.hidden = false/);
    assert.match(plugin, /Timer\s*\{[\s\S]*?launchDelay[\s\S]*?interval:\s*90/);
    assert.match(plugin, /Timer\s*\{[\s\S]*?regionRestore[\s\S]*?interval:\s*900/);

    assert.match(view, /Screenshot region/);
    assert.match(view, /Screenshot screen/);
    assert.match(view, /Record region/);
    assert.match(view, /Record screen/);
    assert.match(view, /Stop recording/);
    assert.match(view, /plugin\.recording/);

    assert.match(builtins, /weatherPlugin,\s*capturePlugin,\s*trayPlugin/);
    assert.match(builtins, /property QtObject capturePlugin:\s*K4CapturePlugin\s*\{\}/);

    assert.match(region, /target:\s*"region"/);
    assert.match(region, /function screenshot\(\)/);
    assert.match(region, /function recordWithSound\(\)/);
    assert.match(recorder, /grim - \| wl-copy/);
    assert.match(recorder, /Directories\.recordScriptPath,\s*"--fullscreen",\s*"--sound"/);
    assert.match(recordScript, /wf-recorder/);

    assert.doesNotMatch(plugin, /gpu-screen-recorder|zenity|editar\.py|transcribir\.py/i);
    assert.doesNotMatch(view, /editor|timeline|transcrib|wallpaper/i);
});
