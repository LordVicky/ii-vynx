const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const hyprland = fs.readFileSync(
    path.join(repoRoot, "dots/.config/hypr/hyprland.lua"),
    "utf8"
);

test("K4 layer leaves expansion motion to QML instead of Hyprland", () => {
    assert.match(
        hyprland,
        /hl\.layer_rule\(\{[\s\S]*?match\s*=\s*\{\s*namespace\s*=\s*"quickshell:k4bar"\s*\}[\s\S]*?no_anim\s*=\s*true[\s\S]*?\}\)/
    );
});
