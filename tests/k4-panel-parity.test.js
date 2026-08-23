import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("sound detail preserves upstream natural-level gain semantics through ii Audio", async () => {
    const audio = await read("services/Audio.qml");
    const adapter = await read("modules/ii/k4bar/K4AudioDevices.qml");
    const view = await read("modules/ii/k4bar/K4PanelAudioView.qml");
    const panel = await read("modules/ii/k4bar/K4PanelPlugin.qml");

    assert.match(audio, /property\s+var\s+baseVolumes:\s*\(\{\}\)/);
    assert.match(audio, /function\s+baseVolumeFor\(node\)/);
    assert.match(audio, /function\s+dbOverNatural\(node\)/);
    assert.match(audio, /function\s+refreshBaseVolumes\(\)/);
    assert.match(audio, /id:\s*baseVolumeReader/);
    assert.match(audio, /pactl list sources/);
    assert.match(audio, /pactl list sinks/);
    assert.match(adapter, /Audio\.baseVolumeFor\(node\)/);
    assert.match(adapter, /Audio\.dbOverNatural\(node\)/);
    assert.match(view, /readonly property int base:\s*K4AudioDevices\.baseFor\(modelData\)/);
    assert.match(view, /readonly property real db:\s*K4AudioDevices\.dbOverNatural\(modelData\)/);
    assert.match(view, /visible:\s*row\.base > 0 && row\.volume > row\.base/);
    assert.match(view, /x:\s*track\.width \* \(row\.base \/ 150\) - 1/);
    assert.match(panel, /tab === "sonido"[\s\S]*?Audio\.refreshBaseVolumes\(\)/);
});

test("sound discovers raw device candidates before view-scoped audio tracking", async () => {
    const audio = await read("services/Audio.qml");
    const adapter = await read("modules/ii/k4bar/K4AudioDevices.qml");
    const view = await read("modules/ii/k4bar/K4PanelAudioView.qml");

    assert.match(audio, /function\s+deviceCandidates\(isSink\)/);
    assert.match(audio, /node\.isSink === isSink && !node\.isStream/);
    assert.match(audio, /readonly property list<var> outputDeviceCandidates:\s*root\.deviceCandidates\(true\)/);
    assert.match(audio, /readonly property list<var> inputDeviceCandidates:\s*root\.deviceCandidates\(false\)/);
    assert.match(audio, /readonly property list<var> outputDevices:\s*root\.devices\(true\)/);
    assert.match(audio, /readonly property list<var> inputDevices:\s*root\.devices\(false\)/);

    assert.match(adapter, /function\s+isPanelDevice\(node\)/);
    assert.match(adapter, /name\.indexOf\("alsa_"\) === 0/);
    assert.match(adapter, /name\.indexOf\("bluez_"\) === 0/);
    assert.match(adapter, /name\.indexOf\("midi"\) < 0/);
    assert.match(adapter, /Audio\.outputDeviceCandidates\.filter\(root\.isPanelDevice\)/);
    assert.match(adapter, /Audio\.inputDeviceCandidates\.filter\(root\.isPanelDevice\)/);
    assert.match(view, /objects:\s*K4AudioDevices\.outputs\.concat\(K4AudioDevices\.inputs\)/);
    assert.match(view, /group\.activeNode && group\.activeNode\.id === modelData\.id/);
});

test("shortcut persistence uses ii-vynx XDG state directory", async () => {
    const settings = await read("modules/ii/k4bar/K4ShortcutSettings.qml");

    assert.match(settings, /import qs\.modules\.common/);
    assert.match(settings, /Directories\.state/);
    assert.doesNotMatch(settings, /Quickshell\.env\("HOME"\)\s*\+\s*"\/\.local\/state/);
});
