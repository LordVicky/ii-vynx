const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const widgetRoot = path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets");

test("legacy resizable widgets do not use parent scene-graph scaling", () => {
    for (const relativePath of [
        "notes/NotesWidget.qml",
        "resources/ResourcesWidget.qml",
        "usercard/UserCardWidget.qml",
        "weather/WeatherWidget.qml",
        "clock/ClockWidget.qml",
        "images/ImageConverterWidget.qml"
    ]) {
        const source = fs.readFileSync(path.join(widgetRoot, relativePath), "utf8");
        assert.doesNotMatch(source, /transformOrigin:\s*Item\.TopLeft/);
        assert.doesNotMatch(source, /\n\s*scale:\s*root\.widgetScale/);
    }
});

test("weather renders authored geometry at its final size", () => {
    const source = fs.readFileSync(path.join(widgetRoot, "weather/WeatherWidget.qml"), "utf8");

    const usesLegacyFinalSizeMetrics = /function scaled\(value\)/.test(source)
        && /pixelSize:\s*root\.scaled\(80\)/.test(source)
        && /iconSize:\s*root\.scaled\(80\)/.test(source)
        && /renderType:\s*Text\.QtRendering/g.test(source);
    const usesCardFinalSizeMetrics = /BackgroundWidgetCard\s*\{/.test(source)
        && /card\.scaled\(/.test(source)
        && /TransformSafeText\s*\{/.test(source)
        && /TransformSafeSymbol\s*\{/.test(source);

    assert.ok(usesLegacyFinalSizeMetrics || usesCardFinalSizeMetrics);
});

test("nested clock content animates authored metrics instead of parent scale", () => {
    const source = fs.readFileSync(path.join(widgetRoot, "clock/CookieClock.qml"), "utf8");

    assert.doesNotMatch(source, /\n\s*scale:\s*1\.4 - 0\.4 \* timeColumnLoader\.shown/);
    assert.match(source, /uiScale:\s*root\.uiScale \* \(1\.4 - 0\.4 \* timeColumnLoader\.shown\)/);
});
