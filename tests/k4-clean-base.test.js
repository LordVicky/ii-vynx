const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const read = relative => fs.readFileSync(path.join(repoRoot, relative), "utf8");

test("k4 branch is independent of the retired glass experiment", () => {
    for (const relative of [
        ".github/workflows/build-hyprglass-backend.yml",
        "dots/.config/quickshell/ii/services/LiquidGlassRuntime.qml",
        "dots/.config/quickshell/ii/services/LiquidGlassSettings.qml",
        "sdata/liquid-glass",
    ]) {
        assert.equal(fs.existsSync(path.join(repoRoot, relative)), false, `${relative} must not exist`);
    }

    const config = read("dots/.config/quickshell/ii/modules/common/Config.qml");
    const family = read("dots/.config/quickshell/ii/panelFamilies/IllogicalImpulseFamily.qml");
    const hyprland = read("dots/.config/hypr/hyprland.lua");

    for (const source of [config, family, hyprland]) {
        assert.doesNotMatch(source, /liquid.?glass|hyprglass|surfaceStyle/i);
    }
});
