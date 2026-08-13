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
