import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");
const executableSource = source => source.replace(/^\s*\/\/.*$/gm, "");

test("panel is a priority-60 explicit island owner with pinned geometry and tabs", async () => {
    const panel = await read("modules/ii/k4bar/K4PanelPlugin.qml");

    assert.match(panel, /name:\s*"panel"/);
    assert.match(panel, /priority:\s*60/);
    assert.match(panel, /active:\s*enabled\s*&&\s*open/);
    assert.match(panel, /property\s+string\s+tab:\s*"controls"/);
    assert.match(panel, /property\s+bool\s+open:\s*false/);
    assert.match(panel, /islandWidth:\s*860/);
    assert.match(panel, /islandHeight:\s*tab\s*===\s*"controls"\s*\?\s*268\s*:\s*400/);
    assert.match(panel, /grabKeyboard:\s*open/);
    assert.match(panel, /handlesBackgroundTap:\s*true/);
    assert.match(panel, /closeOnHoverExit:\s*true/);
    assert.match(panel, /function\s+openTab\s*\(wanted\)/);
    assert.match(panel, /function\s+toggle\s*\(wanted\)/);
    assert.match(panel, /K4PanelView\s*\{/);

    for (const tab of ["controls", "notifications", "wifi", "bluetooth", "sonido"])
        assert.match(panel, new RegExp(`"${tab}"`));
});

test("unhandled island background taps open panel Controls on the clicked screen", async () => {
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(builtins, /panelPlugin/);
    assert.match(builtins, /K4PanelPlugin\s*\{/);
    assert.match(controller, /IslandState\.requestScreen\(screenName\)/);
    assert.match(controller, /plugin\("panel"\)/);
    assert.match(controller, /panel\.openTab\("controls"\)/);

    const backgroundTap = controller.match(/function\s+backgroundTap\(screenName\)\s*\{([\s\S]*?)\n\s*\}/)?.[1] ?? "";
    assert.match(backgroundTap, /handlesBackgroundTap/);
    assert.match(backgroundTap, /backgroundTapped\(\)/);
    assert.match(backgroundTap, /openTab\("controls"\)/);
});

test("panel adapters delegate to existing ii service owners", async () => {
    const wifi = executableSource(await read("modules/ii/k4bar/K4Wifi.qml"));
    const bluetooth = executableSource(await read("modules/ii/k4bar/K4Bluetooth.qml"));
    const audio = executableSource(await read("modules/ii/k4bar/K4AudioDevices.qml"));

    assert.match(wifi, /Network\.friendlyWifiNetworks/);
    assert.match(wifi, /Network\.toggleWifi\(\)/);
    assert.match(wifi, /Network\.rescanWifi\(\)/);
    assert.match(wifi, /Network\.connectToWifiNetwork\(/);
    assert.doesNotMatch(wifi, /Process\s*\{/);
    assert.doesNotMatch(wifi, /nmcli/);

    assert.match(bluetooth, /BluetoothStatus\.friendlyDeviceList/);
    assert.match(bluetooth, /Bluetooth\.defaultAdapter/);
    assert.doesNotMatch(bluetooth, /Process\s*\{/);

    assert.match(audio, /Audio\.outputDevices/);
    assert.match(audio, /Audio\.inputDevices/);
    assert.match(audio, /Audio\.setDefaultSink\(/);
    assert.match(audio, /Audio\.setDefaultSource\(/);
    assert.doesNotMatch(audio, /PwObjectTracker\s*\{/);
});

test("panel controls compose existing K4 media, notification, clock and workspace seams", async () => {
    const view = await read("modules/ii/k4bar/K4PanelView.qml");

    assert.match(view, /K4Wifi/);
    assert.match(view, /K4Bluetooth/);
    assert.match(view, /K4Audio/);
    assert.match(view, /K4Media/);
    assert.match(view, /K4Notifications/);
    assert.match(view, /K4Clock/);
    assert.match(view, /K4Workspaces/);
    assert.match(view, /K4PanelWifiView\s*\{/);
    assert.match(view, /K4PanelBluetoothView\s*\{/);
    assert.match(view, /K4PanelAudioView\s*\{/);
    assert.match(view, /K4PanelNotificationsView\s*\{/);
    assert.match(view, /K4ShortcutStrip\s*\{/);
});

test("shortcut strip persists upstream ids but renders only live K4 targets", async () => {
    const config = await read("modules/common/Config.qml");
    const shortcuts = await read("modules/ii/k4bar/K4ShortcutStrip.qml");

    assert.match(config, /property\s+var\s+shortcuts:\s*\[\s*"game",\s*"hyprtheme",\s*"system",\s*"clipboard"\s*\]/);
    assert.match(shortcuts, /Config\.options\.bar\.k4\.shortcuts/);
    assert.match(shortcuts, /controller\.plugin\(/);
    assert.match(shortcuts, /enabled/);
    assert.match(shortcuts, /function\s+slotFor\s*\(/);
    assert.match(shortcuts, /function\s+applyReorder\s*\(/);
    assert.match(shortcuts, /dragging/);
    assert.match(shortcuts, /destination/);
    assert.match(shortcuts, /Config\.options\.bar\.k4\.shortcuts\s*=/);
    assert.match(shortcuts, /name:\s*"All"/);
    assert.match(shortcuts, /controller\.plugin\("apps"\)/);
});

test("panel detail views expose Wi-Fi, Bluetooth, audio and full notification actions", async () => {
    const wifi = await read("modules/ii/k4bar/K4PanelWifiView.qml");
    const bluetooth = await read("modules/ii/k4bar/K4PanelBluetoothView.qml");
    const audio = await read("modules/ii/k4bar/K4PanelAudioView.qml");
    const notifications = await read("modules/ii/k4bar/K4PanelNotificationsView.qml");

    assert.match(wifi, /K4Wifi\.networks/);
    assert.match(wifi, /K4Wifi\.toggle\(\)/);
    assert.match(wifi, /K4Wifi\.activate\(/);
    assert.match(wifi, /password/);

    assert.match(bluetooth, /K4Bluetooth\.devices/);
    assert.match(bluetooth, /K4Bluetooth\.toggle\(\)/);
    assert.match(bluetooth, /K4Bluetooth\.activate\(/);

    assert.match(audio, /K4AudioDevices\.outputs/);
    assert.match(audio, /K4AudioDevices\.inputs/);
    assert.match(audio, /K4AudioDevices\.selectOutput\(/);
    assert.match(audio, /K4AudioDevices\.selectInput\(/);

    assert.match(notifications, /K4Notifications\.history/);
    assert.match(notifications, /K4Notifications\.clear\(\)/);
    assert.match(notifications, /K4Notifications\.dismiss\(/);
    assert.match(notifications, /K4Notifications\.activate\(/);
});

test("player output control opens the K4 sound panel instead of an ii sidebar", async () => {
    const player = executableSource(await read("modules/ii/k4bar/K4PlayerView.qml"));

    assert.match(player, /K4Panel\.openTab\("sonido"\)/);
    assert.doesNotMatch(player, /sidebar/i);
});
