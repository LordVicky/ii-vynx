const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

test("battery device sources and layout have persisted defaults", () => {
    const config = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/common/Config.qml"),
        "utf8"
    );
    const battery = config.match(/property JsonObject battery: JsonObject \{([\s\S]*?)\n\s*\}/)?.[1] ?? "";

    assert.match(battery, /property string layout: "list"/);
    assert.match(battery, /property bool showLaptopBattery: true/);
    assert.match(battery, /property bool showBluetoothBatteries: true/);
    assert.match(battery, /property bool showAppleBatteries: true/);
    assert.match(battery, /property int applePollingMinutes: 15/);
});

test("battery card uses shared desktop widget canvas widths", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.match(widget, /DesktopWidgetMetrics\.canvas\.compact/);
    assert.match(widget, /DesktopWidgetMetrics\.canvas\.standard/);
});

test("battery rings use the success color from 90 percent upward", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.match(widget, /percentage >= 0\.9/);
    assert.match(widget, /Appearance\.m3colors\.m3success/);
});

test("battery status colors are boosted for wallpaper contrast", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.match(widget, /function vividBatteryColor\(color, hueOverride = -1, saturationFloor = 0\.45, lightnessOverride = -1\)/);
    assert.match(widget, /Math\.max\(saturationFloor, source\.hslSaturation \* 1\.75\)/);
    assert.match(widget, /Math\.max\(0\.6, source\.hslLightness \* 1\.08\)/);
    assert.match(widget, /vividBatteryColor\(Appearance\.colors\.colError/);
    assert.match(widget, /vividBatteryColor\(Appearance\.colors\.colTertiary\)/);
});

test("low battery color uses an Apple-style red hue", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.match(widget, /vividBatteryColor\(Appearance\.colors\.colError, 0\.0, 0\.75, 0\.58\)/);
});

test("shared battery rings render charging inside the ring", () => {
    const ring = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml"),
        "utf8"
    );
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.match(ring, /property bool charging: false/);
    assert.match(ring, /visible: root\.charging/);
    assert.match(ring, /import QtQuick\.Shapes/);
    assert.match(ring, /Shape \{[\s\S]*id: chargingBolt[\s\S]*anchors\.centerIn: parent/);
    assert.match(ring, /readonly property bool smallRing: ringSize <= 40 \* scaleFactor/);
    assert.match(ring, /width: root\.ringSize \* \(root\.smallRing \? 0\.34 : 0\.27\)/);
    assert.match(ring, /height: root\.ringSize \* \(root\.smallRing \? 0\.40 : 0\.31\)/);
    assert.match(ring, /strokeWidth: Math\.max\(0\.6, chargingBolt\.width \* 0\.055\)/);
    assert.match(ring, /fillColor: root\.ringColor/);
    assert.match(ring, /strokeColor: root\.ringColor/);
    assert.match(ring, /joinStyle: ShapePath\.RoundJoin/);
    assert.match(ring, /capStyle: ShapePath\.RoundCap/);
    assert.doesNotMatch(ring, /Canvas \{/);
    assert.doesNotMatch(ring, /chargingOverlay/);
    assert.doesNotMatch(ring, /chargingColor/);
    assert.match(widget, /charging: deviceRow\.chargingActive/);
    assert.match(widget, /charging: compactContent\.chargingActive/);
    assert.doesNotMatch(widget, /chargingColor:/);
});

test("battery full rows no longer render a separate charging indicator", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.doesNotMatch(widget, /id: chargingSlot/);
    assert.doesNotMatch(widget, /text: "bolt"/);
});

test("battery ring thickness changes without changing ring sizes", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.match(widget, /ringSize: card\.scaled\(root\.rowHeight\)[\s\S]*lineWidth: card\.scaled\(4\)/);
    assert.match(widget, /ringSize: card\.scaled\(56\)[\s\S]*lineWidth: card\.scaled\(6\)/);
});

test("high battery color uses a true green hue", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );

    assert.match(widget, /vividBatteryColor\(Appearance\.m3colors\.m3success, 0\.39, 0\.62, 0\.58\)/);
});

test("Apple battery devices use dedicated glyphs in list and compact layouts", () => {
    const devices = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryDevices.qml"),
        "utf8"
    );
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml"),
        "utf8"
    );
    const ring = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml"),
        "utf8"
    );
    const customIcon = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/common/widgets/CustomIcon.qml"),
        "utf8"
    );

    assert.match(devices, /function appleCustomIcon\(deviceClass\)/);
    assert.match(devices, /return "apple-iphone-symbolic\.svg"/);
    assert.match(devices, /return "apple-watch-symbolic\.svg"/);
    assert.match(devices, /return "apple-airpods-symbolic\.svg"/);
    assert.match(devices, /customIcon: root\.appleCustomIcon\(device\.deviceClass\)/);

    assert.match(widget, /property string compactCustomIcon: ""/);
    assert.match(widget, /required property string customIcon/);
    assert.match(widget, /customIcon: device\.customIcon/);
    assert.match(widget, /deviceModel\.setProperty\(currentIndex, "customIcon", device\.customIcon\)/);
    assert.match(widget, /AppleDeviceGlyph \{[\s\S]*source: deviceRow\.customIcon/);
    assert.match(widget, /readonly property color foregroundColor: stale[\s\S]*\? root\.adaptiveSubtextColor[\s\S]*: Appearance\.colors\.colOnLayer0/);
    assert.match(widget, /source: deviceRow\.customIcon[\s\S]*color: deviceRow\.foregroundColor/);
    assert.match(widget, /text: deviceRow\.icon[\s\S]*color: deviceRow\.foregroundColor/);
    assert.match(widget, /text: deviceRow\.stale[\s\S]*color: deviceRow\.foregroundColor/);
    assert.match(widget, /centerCustomIcon: root\.compactCustomIcon/);

    assert.match(ring, /property string centerCustomIcon: ""/);
    assert.match(ring, /AppleDeviceGlyph \{[\s\S]*source: root\.centerCustomIcon/);
    assert.doesNotMatch(customIcon, /sourceSize/);

    const appleGlyph = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/AppleDeviceGlyph.qml"),
        "utf8"
    );
    assert.match(appleGlyph, /readonly property bool iphone:/);
    assert.match(appleGlyph, /readonly property bool watch:/);
    assert.match(appleGlyph, /readonly property bool airpods:/);
    assert.match(appleGlyph, /id: watchCase[\s\S]*width: Math\.round\(root\.width \* 0\.62\)[\s\S]*height: Math\.round\(root\.height \* 0\.76\)/);
    assert.doesNotMatch(appleGlyph, /root\.width \* 0\.28/);
    assert.doesNotMatch(appleGlyph, /CustomIcon|ColorOverlay|IconImage/);

    for (const filename of [
        "apple-iphone-symbolic.svg",
        "apple-watch-symbolic.svg",
        "apple-airpods-symbolic.svg"
    ]) {
        const glyph = fs.readFileSync(
            path.join(__dirname, "../dots/.config/quickshell/ii/assets/icons", filename),
            "utf8"
        );
        assert.match(glyph, /viewBox="0 0 24 24"/);
        assert.doesNotMatch(glyph, /stroke=/);
    }
});

test("remote battery freshness advances independently of polling", () => {
    const service = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/services/AppleBatteryStatus.qml"),
        "utf8"
    );
    const devices = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryDevices.qml"),
        "utf8"
    );

    assert.match(service, /property double freshnessClock: Date\.now\(\)/);
    assert.match(service, /id: freshnessTimer/);
    assert.match(service, /running: root\.devices\.length > 0/);
    assert.match(service, /root\.pruneExpiredDevices\(\)/);
    assert.match(service, /payload\.state !== "notConfigured"/);
    assert.match(service, /root\.state = "disconnectError"/);
    assert.match(devices, /AppleBatteryStatus\.freshnessClock/);
});

test("Apple sign-in passes the helper as a positional argument and reports failures", () => {
    const service = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/services/AppleBatteryStatus.qml"),
        "utf8"
    );

    const login = service.match(/function openLogin\(\) \{([\s\S]*?)\n    \}/)?.[1] ?? "";
    assert.match(login, /"\$1" login/);
    assert.match(login, /vynx-apple-battery-login/);
    assert.match(login, /root\.shellQuote\(root\.helperPath\)/);
    assert.match(login, /if \[ \$status -eq 0 \]/);
    assert.match(login, /Sign-in failed/);
    assert.doesNotMatch(login, /const helper = root\.shellQuote/);
});

test("Apple settings disclose keyring storage and disconnect cleanup", () => {
    const settings = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/settings/AppleBatterySettings.qml"),
        "utf8"
    );

    assert.match(settings, /encrypted system keyring/);
    assert.match(settings, /removed when you press Disconnect/);
});
