const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const controllerPath = path.join(
    repoRoot,
    "dots/.config/quickshell/ii/modules/ii/k4bar/K4PluginController.qml"
);

test("bottom passive hover keeps the geometry re-entry grace through expansion", () => {
    const source = fs.readFileSync(controllerPath, "utf8")
        .replace(/^\s*\/\/.*$/gm, "");

    assert.match(
        source,
        /function hoverExitGraceMs\(\)[\s\S]*?K4Settings\.position === "bottom"[\s\S]*?isPassiveHoverPlugin\(activePlugin\)[\s\S]*?\? 520 : 240/
    );
    assert.match(
        source,
        /function hoverExited\(\)[\s\S]*?hoverClearTimer\.interval = hoverExitGraceMs\(\)[\s\S]*?hoverClearTimer\.restart\(\)[\s\S]*?armPluginHoverExit\(\)/
    );
});
