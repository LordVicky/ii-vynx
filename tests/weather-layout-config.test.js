const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");

test("weather layout cycling has a persisted config property", () => {
    const config = fs.readFileSync(path.join(root, "modules/common/Config.qml"), "utf8");
    const widget = fs.readFileSync(
        path.join(root, "modules/ii/background/widgets/weather/WeatherWidget.qml"),
        "utf8"
    );
    const weatherConfig = config.match(/property JsonObject weather: JsonObject \{([\s\S]*?)\n\s*\}/)?.[1];

    assert.ok(weatherConfig, "weather config block not found");
    assert.match(weatherConfig, /property string layout: "card"/);
    assert.match(widget, /root\.configEntry\.layout = root\.layoutOrder/);
});
