import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("K4 Settings is an in-island application backed by existing bar config", async () => {
    const adapter = await read("modules/ii/k4bar/K4Settings.qml");
    const plugin = await read("modules/ii/k4bar/K4SettingsPlugin.qml");
    const view = await read("modules/ii/k4bar/K4SettingsView.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(adapter, /Config\.options\.bar\.k4\.position/);
    assert.match(adapter, /Config\.options\.bar\.k4\.alignment/);
    assert.match(adapter, /function setPosition\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.position = value/);
    assert.match(adapter, /function setAlignment\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.alignment = value/);
    assert.doesNotMatch(adapter, /FileView|\.local\/state|JsonAdapter/);

    assert.match(plugin, /name:\s*"settings"/);
    assert.match(plugin, /priority:\s*66/);
    assert.match(plugin, /application:\s*true/);
    assert.match(plugin, /active:\s*enabled\s*&&\s*open/);
    assert.match(plugin, /islandWidth:\s*600/);
    assert.match(plugin, /islandHeight:\s*640/);
    assert.match(plugin, /grabKeyboard:\s*open/);
    assert.match(plugin, /closeOnHoverExit:\s*true/);
    assert.match(plugin, /hoverExitDelay:\s*1200/);
    assert.match(plugin, /function openApplication\(\)[\s\S]*?openSettings\(\)/);
    assert.match(plugin, /K4Panel\.close\(\)/);
    assert.match(plugin, /target:\s*"k4\.settings"/);

    assert.match(view, /K4Settings\.positions/);
    assert.match(view, /K4Settings\.setPosition\(/);
    assert.match(view, /K4Settings\.alignments/);
    assert.match(view, /K4Settings\.setAlignment\(/);
    assert.doesNotMatch(view, /captura|editor|juego|plugin store/i);

    assert.match(builtins, /appsPlugin, settingsPlugin, launcherPlugin/);
    assert.match(builtins, /property QtObject settingsPlugin:\s*K4SettingsPlugin\s*\{\}/);
});

test("K4 Island preferences are persisted in Config and consumed by live features", async () => {
    const config = await read("modules/common/Config.qml");
    const adapter = await read("modules/ii/k4bar/K4Settings.qml");
    const view = await read("modules/ii/k4bar/K4SettingsView.qml");
    const idle = await read("modules/ii/k4bar/K4IdlePill.qml");
    const host = await read("modules/ii/k4bar/K4Bar.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const clock = await read("modules/ii/k4bar/K4ClockView.qml");
    const player = await read("modules/ii/k4bar/K4PlayerView.qml");
    const notifications = await read("modules/ii/k4bar/K4Notifications.qml");

    assert.match(config, /property JsonObject k4: JsonObject \{[\s\S]*?property bool trayInPill:\s*false[\s\S]*?property bool notificationsOnHover:\s*true[\s\S]*?property bool dismissNotificationsOnFocus:\s*true/);
    assert.match(adapter, /readonly property bool trayInPill:\s*Config\.options\.bar\.k4\.trayInPill/);
    assert.match(adapter, /readonly property bool notificationsOnHover:\s*Config\.options\.bar\.k4\.notificationsOnHover/);
    assert.match(adapter, /readonly property bool dismissNotificationsOnFocus:\s*Config\.options\.bar\.k4\.dismissNotificationsOnFocus/);
    assert.match(adapter, /function setTrayInPill\(wanted\)/);
    assert.match(adapter, /function setNotificationsOnHover\(wanted\)/);
    assert.match(adapter, /function setDismissNotificationsOnFocus\(wanted\)/);

    assert.match(host, /K4IdlePill\s*\{[\s\S]*?trayPlugin:\s*controller\.builtins\.trayPlugin/);
    assert.match(idle, /property var trayPlugin:\s*null/);
    assert.match(idle, /K4TrayRow\s*\{[\s\S]*?K4Settings\.trayInPill[\s\S]*?max:\s*4/);

    assert.match(builtins, /notificationStripHeight:\s*K4Settings\.notificationsOnHover\s*\?\s*K4Notifications\.stripHeight\(3\)\s*:\s*0/g);
    assert.match(clock, /K4NotifStrip\s*\{[\s\S]*?visible:\s*K4Settings\.notificationsOnHover/);
    assert.match(player, /K4NotifStrip\s*\{[\s\S]*?visible:\s*K4Settings\.notificationsOnHover/);

    assert.match(notifications, /import Quickshell\.Hyprland/);
    assert.match(notifications, /HyprlandData\.clientForToplevel\(toplevel\)/);
    assert.match(notifications, /function dismissFocused\(toplevel\)[\s\S]*?K4Settings\.dismissNotificationsOnFocus/);
    assert.match(notifications, /target:\s*Hyprland[\s\S]*?onActiveToplevelChanged[\s\S]*?dismissFocused\(Hyprland\.activeToplevel\)/);

    assert.match(view, /K4SettingsToggle/);
    assert.match(view, /K4Settings\.setTrayInPill\(/);
    assert.match(view, /K4Settings\.setNotificationsOnHover\(/);
    assert.match(view, /K4Settings\.setDismissNotificationsOnFocus\(/);
});
