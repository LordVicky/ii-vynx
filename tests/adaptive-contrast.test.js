const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const sourcePath = path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/AdaptiveContrast.js");
const source = fs.readFileSync(sourcePath, "utf8");
const contrast = {};
vm.createContext(contrast);
vm.runInContext(source, contrast, { filename: sourcePath });

test("relative luminance follows WCAG endpoints", () => {
    assert.equal(contrast.relativeLuminance(0, 0, 0), 0);
    assert.equal(contrast.relativeLuminance(255, 255, 255), 1);
});

test("average luminance averages pixels and ignores alpha", () => {
    const data = [0, 0, 0, 0, 255, 255, 255, 17];
    assert.equal(contrast.averageLuminance(data), 0.5);
    assert.equal(contrast.averageLuminance([]), -1);
});

test("automatic scrim is bounded and monotonic", () => {
    assert.equal(contrast.automaticScrimOpacity(0.35), 0);
    assert.equal(contrast.automaticScrimOpacity(0.65), 0.32);
    assert.equal(contrast.automaticScrimOpacity(1), 0.32);
    const lower = contrast.automaticScrimOpacity(0.4);
    const upper = contrast.automaticScrimOpacity(0.55);
    assert.ok(lower > 0);
    assert.ok(upper > lower);
});

test("effective luminance accounts for the automatic black scrim", () => {
    assert.ok(Math.abs(contrast.effectiveLuminance(0.8, 0.25) - 0.6) < 1e-9);
    assert.equal(contrast.effectiveLuminance(2, -1), 1);
});

test("adaptive text decision uses hysteresis", () => {
    assert.equal(contrast.shouldUseDarkText(0.47, false), false);
    assert.equal(contrast.shouldUseDarkText(0.48, false), true);
    assert.equal(contrast.shouldUseDarkText(0.45, true), true);
    assert.equal(contrast.shouldUseDarkText(0.43, true), false);
});

test("cover crop converts a landscape image into a square display", () => {
    const crop = contrast.coverSourceRect({ x: 0, y: 0, width: 1, height: 1 }, 100, 100, 200, 100);
    assert.deepEqual({ ...crop }, { x: 50, y: 0, width: 100, height: 100 });
});

test("cover crop converts a portrait image into a landscape display", () => {
    const crop = contrast.coverSourceRect({ x: 0, y: 0, width: 1, height: 1 }, 200, 100, 100, 200);
    assert.deepEqual({ ...crop }, { x: 0, y: 75, width: 100, height: 50 });
});

test("cover crop clamps a partially off-screen normalized rectangle", () => {
    const crop = contrast.coverSourceRect({ x: -0.25, y: 0.25, width: 0.75, height: 1 }, 100, 100, 100, 100);
    assert.deepEqual({ ...crop }, { x: 0, y: 25, width: 50, height: 75 });
});

test("a failed sample clears stale automatic contrast", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/WidgetBlurBackground.qml"),
        "utf8"
    );

    assert.match(widget, /function clearContrastSample\(\) \{[\s\S]*?_sampledLuminance = -1;[\s\S]*?_useDarkSubtext = false;[\s\S]*?\}/);
    assert.match(widget, /if \(luminance < 0\) \{[\s\S]*?clearContrastSample\(\);[\s\S]*?return;/);
});

test("unavailable sampling geometry clears stale automatic contrast", () => {
    const widget = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/WidgetBlurBackground.qml"),
        "utf8"
    );

    assert.match(widget, /function clearContrastSample\(\)/);
    assert.match(widget, /wallpaperPath === "" \|\| root\.width <= 0 \|\| root\.height <= 0\) \{[\s\S]*?clearContrastSample\(\);[\s\S]*?return;/);
    assert.match(widget, /crop === null\) \{[\s\S]*?clearContrastSample\(\);[\s\S]*?return;/);
});
