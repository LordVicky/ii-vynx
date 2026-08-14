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
