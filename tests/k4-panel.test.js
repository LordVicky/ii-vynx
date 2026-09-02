import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");
const executableSource = source => source.replace(/^\s*\/\/.*$/gm, "");

test("panel is a priority-60 explicit island owner with prototype geometry and tabs", async () => {
    const panel = await read("modules/ii/k4bar/K4PanelPlugin.qml");

    assert.match(panel, /name:\s*"panel"/);
    assert.match(panel, /priority:\s*60/);
    assert.match(panel, /active:\s*enabled\s*&&\s*open/);
    assert.match(panel, /property\s+string\s+tab:\s*"controls"/);
    assert.match(panel, /property\s+bool\s+open:\s*false/);
    assert.match(panel, /islandWidth:\s*690/);
    assert.match(panel, /islandHeight:\s*430/);
    assert.match(panel, /grabKeyboard:\s*open/);
    assert.match(panel, /handlesBackgroundTap:\s*true/);
    assert.match(panel, /closeOnHoverExit:\s*true/);
    assert.match(panel, /function\s+openTab\s*\(wanted\)/);
    assert.match(panel, /function\s+toggle\s*\(wanted\)/);
    assert.match(panel, /K4PanelView\s*\{/);

    for (const tab of ["controls", "notifications", "wifi", "bluetooth", "sonido"])
        assert.match(panel, new RegExp(`"${tab}"`));
});

test("panel navigation clears pending Wi-Fi password state", async () => {
    const panel = await read("modules/ii/k4bar/K4PanelPlugin.qml");

    assert.match(panel, /function\s+openTab\(wanted\)\s*\{[\s\S]*?K4Wifi\.cancelPassword\(\)[\s\S]*?tab = wanted[\s\S]*?open = true/);
});

test("unhandled island background taps open panel Controls on the clicked screen", async () => {
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");
    const builtins = await read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(builtins, /panelPlugin/);
    assert.match(builtins, /K4PanelPlugin\s*\{/);
    assert.match(controller, /function\s+backgroundTap\(screenName\)/);
    assert.match(controller, /handlesBackgroundTap/);
    assert.match(controller, /backgroundTapped\(\)/);
    assert.match(controller, /IslandState\.requestScreen\(screenName\)/);
    assert.match(controller, /plugin\("panel"\)/);
    assert.match(controller, /panel\.openTab\("controls"\)/);
});

test("controller injects the live registry into Panel for desktop tool targets", async () => {
    const controller = await read("modules/ii/k4bar/K4PluginController.qml");

    assert.match(controller, /Component\.onCompleted:\s*\{[\s\S]*?attachBuiltins\(\)[\s\S]*?const panel = plugin\("panel"\)[\s\S]*?panel\.controller = root[\s\S]*?publishActivePlugin\(\)/);
    assert.match(controller, /function\s+reset\(\)[\s\S]*?panel\?\.controller === root[\s\S]*?panel\.controller = null/);
});

test("panel scans and discovers only while the matching detail is open", async () => {
    const panel = await read("modules/ii/k4bar/K4PanelPlugin.qml");

    assert.match(panel, /K4Bluetooth\.setDiscovering\(open\s*&&\s*tab\s*===\s*"bluetooth"\)/);
    assert.match(panel, /open\s*&&\s*tab\s*===\s*"wifi"\s*&&\s*K4Wifi\.enabled/);
    assert.match(panel, /K4Wifi\.scan\(\)/);
    assert.match(panel, /onOpenChanged:\s*syncDetailActivity\(\)/);
    assert.match(panel, /onTabChanged:\s*syncDetailActivity\(\)/);
});

test("panel adapters delegate to existing ii service owners", async () => {
    const wifi = executableSource(await read("modules/ii/k4bar/K4Wifi.qml"));
    const bluetooth = executableSource(await read("modules/ii/k4bar/K4Bluetooth.qml"));
    const audio = executableSource(await read("modules/ii/k4bar/K4AudioDevices.qml"));

    assert.match(wifi, /Network\.friendlyWifiNetworks/);
    assert.match(wifi, /Network\.toggleWifi\(\)/);
    assert.match(wifi, /Network\.rescanWifi\(\)/);
    assert.match(wifi, /Network\.connectToWifiNetwork\(/);
    assert.match(wifi, /Network\.forgetWifiNetwork\(/);
    assert.doesNotMatch(wifi, /Process\s*\{/);
    assert.doesNotMatch(wifi, /nmcli/);

    assert.match(bluetooth, /BluetoothStatus\.friendlyDeviceList/);
    assert.match(bluetooth, /Bluetooth\.defaultAdapter/);
    assert.match(bluetooth, /const target = Boolean\(wanted\)[\s\S]*?if \(current\.discovering === target\)[\s\S]*?return[\s\S]*?current\.discovering = target/);
    assert.doesNotMatch(bluetooth, /Process\s*\{/);

    assert.match(audio, /Audio\.outputDeviceCandidates/);
    assert.match(audio, /Audio\.inputDeviceCandidates/);
    assert.match(audio, /Audio\.setDefaultSink\(/);
    assert.match(audio, /Audio\.setDefaultSource\(/);
    assert.doesNotMatch(audio, /PwObjectTracker\s*\{/);
});

test("existing Network owner exposes saved Wi-Fi state and forgetting for k4 parity", async () => {
    const network = await read("services/Network.qml");
    const accessPoint = await read("services/network/WifiAccessPoint.qml");

    assert.match(network, /property\s+list<string>\s+wifiKnownSsids:\s*\[\]/);
    assert.match(network, /function\s+forgetWifiNetwork\(accessPoint:\s*WifiAccessPoint\)/);
    assert.match(network, /id:\s*knownWifiProfiles/);
    assert.match(network, /id:\s*forgetWifiProc/);
    assert.match(network, /known:\s*root\.wifiKnownSsids\.indexOf\(net\[3\]\)\s*>=\s*0/);
    assert.match(accessPoint, /readonly property bool known:/);
});

test("Network keeps a concrete retry target through Wi-Fi password replacement", async () => {
    const network = await read("services/Network.qml");

    assert.match(network, /function\s+changePassword\(network:[\s\S]*?root\.wifiConnectTarget = network[\s\S]*?changePasswordProc\.exec/);
    assert.match(network, /onExited:\s*\(exitCode, exitStatus\)\s*=>\s*\{[\s\S]*?const target = root\.wifiConnectTarget[\s\S]*?if \(target\)[\s\S]*?target\.askingPassword = \(exitCode !== 0\)[\s\S]*?root\.wifiConnectTarget = null/);
    assert.match(network, /if \(line\.includes\("Secrets were required"\)\)[\s\S]*?if \(root\.wifiConnectTarget\)[\s\S]*?root\.wifiConnectTarget\.askingPassword = true/);
});

test("control center v2 preserves the prototype home hierarchy with live K4 seams", async () => {
    const view = await read("modules/ii/k4bar/K4PanelView.qml");

    assert.match(view, /Layout\.preferredWidth:\s*350/);
    assert.match(view, /Layout\.preferredHeight:\s*84/);
    assert.match(view, /Layout\.preferredHeight:\s*94/);
    assert.match(view, /Layout\.preferredHeight:\s*142/);
    assert.match(view, /columns:\s*3[\s\S]*?rows:\s*2/);
    assert.match(view, /columns:\s*2[\s\S]*?rows:\s*2/);

    for (const seam of ["K4Wifi", "K4Bluetooth", "K4Audio", "K4Media", "K4Notifications", "K4Clock", "K4Workspaces", "K4Weather"])
        assert.match(view, new RegExp(seam));

    for (const title of ["Capture", "Record", "Clipboard", "Windows", "Displays", "Settings", "Files", "System", "Weather", "Session"])
        assert.match(view, new RegExp(`"${title}"`));

    assert.match(view, /function\s+launch\(name\)[\s\S]*?controller\?\.plugin/);
    assert.match(view, /openApplication/);
    assert.doesNotMatch(view, /K4ShortcutStrip\s*\{/);
});

test("record tile delegates to Capture and becomes stop while recording", async () => {
    const view = await read("modules/ii/k4bar/K4PanelView.qml");
    const capture = await read("modules/ii/k4bar/K4CapturePlugin.qml");

    assert.match(view, /readonly property bool recording:\s*captureTarget\?\.recording/);
    assert.match(view, /function\s+openRecord\(\)[\s\S]*?if \(capture\.recording\)[\s\S]*?capture\.stopRecording\(\)[\s\S]*?capture\.openRecord\(\)/);
    assert.match(view, /title:\s*root\.recording\s*\?\s*"Stop Recording"\s*:\s*"Record"/);
    assert.match(capture, /function\s+openRecord\(\)\s*\{\s*openAt\(2\)\s*\}/);
});

test("prototype mock telemetry is not hard-coded into the live panel", async () => {
    const sources = [
        await read("modules/ii/k4bar/K4PanelView.qml"),
        await read("modules/ii/k4bar/K4PanelWifiView.qml"),
        await read("modules/ii/k4bar/K4PanelBluetoothView.qml")
    ].join("\n");

    for (const mock of ["Vynx-5G", "866 Mbps", "18.4 Mbps", "192.168.1.87", "Wi-Fi 6", "AirPods Pro", "82%", "91%"])
        assert.doesNotMatch(sources, new RegExp(mock.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
});

test("panel detail views expose Wi-Fi, Bluetooth, audio and full notification actions", async () => {
    const wifi = await read("modules/ii/k4bar/K4PanelWifiView.qml");
    const bluetooth = await read("modules/ii/k4bar/K4PanelBluetoothView.qml");
    const audio = await read("modules/ii/k4bar/K4PanelAudioView.qml");
    const notifications = await read("modules/ii/k4bar/K4PanelNotificationsView.qml");

    assert.match(wifi, /K4Wifi\.networks/);
    assert.match(wifi, /K4Wifi\.toggle\(\)/);
    assert.match(wifi, /K4Wifi\.activate\(/);
    assert.match(wifi, /forgettable:\s*modelData\.known/);
    assert.match(wifi, /onForgotten:\s*K4Wifi\.forget\(modelData\)/);
    assert.match(wifi, /password/i);
    assert.match(wifi, /RowLayout\s*\{[\s\S]*?Available networks[\s\S]*?Connection/);

    assert.match(bluetooth, /K4Bluetooth\.devices/);
    assert.match(bluetooth, /K4Bluetooth\.toggle\(\)/);
    assert.match(bluetooth, /K4Bluetooth\.activate\(/);
    assert.match(bluetooth, /onForgotten:\s*K4Bluetooth\.togglePair/);
    assert.match(bluetooth, /myDevices/);
    assert.match(bluetooth, /nearbyDevices/);

    assert.match(audio, /K4AudioDevices\.outputs/);
    assert.match(audio, /K4AudioDevices\.inputs/);
    assert.match(audio, /K4AudioDevices\.selectOutput\(/);
    assert.match(audio, /K4AudioDevices\.selectInput\(/);
    assert.match(audio, /DevicePane/);

    assert.match(notifications, /K4Notifications\.history/);
    assert.match(notifications, /K4Notifications\.dismiss\(/);
    assert.match(notifications, /K4Notifications\.activate\(/);
    assert.match(notifications, /K4Notifications\.invokeAction\(/);
    const panel = await read("modules/ii/k4bar/K4PanelView.qml");
    assert.match(panel, /K4Notifications\.clear\(\)/);
});

test("Wi-Fi password prompt takes focus and consumes Escape or Enter before the panel", async () => {
    const wifi = await read("modules/ii/k4bar/K4PanelWifiView.qml");

    assert.match(wifi, /Connections\s*\{[\s\S]*?target:\s*K4Wifi[\s\S]*?onPasswordTargetChanged[\s\S]*?passwordInput\.forceActiveFocus\(\)/);
    assert.match(wifi, /Keys\.onPressed:\s*function\s*\(event\)[\s\S]*?Qt\.Key_Escape[\s\S]*?K4Wifi\.cancelPassword\(\)[\s\S]*?event\.accepted = true/);
    assert.match(wifi, /Qt\.Key_Return\s*\|\|\s*event\.key === Qt\.Key_Enter[\s\S]*?K4Wifi\.submitPassword\(\)[\s\S]*?event\.accepted = true/);
});

test("panel notifications close the panel and take the normal toast path", async () => {
    const panel = await read("modules/ii/k4bar/K4PanelPlugin.qml");
    const notifications = await read("modules/ii/k4bar/K4Notifications.qml");

    assert.match(panel, /function\s+onNotify\(notification\)\s*\{\s*root\.open\s*=\s*false\s*\}/);
    assert.match(notifications, /passiveToastOwners:[^\n]*"panel"/);
});

test("player output control opens the K4 sound panel instead of an ii sidebar", async () => {
    const player = executableSource(await read("modules/ii/k4bar/K4PlayerView.qml"));

    assert.match(player, /K4Panel\.openTab\("sonido"\)/);
    assert.doesNotMatch(player, /sidebar/i);
});
