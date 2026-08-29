const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(shellRoot, name), "utf8")
    .replace(/^\s*\/\/.*$/gm, "");

test("bottom hover continuity uses a stable collapsed footprint instead of a longer timeout", () => {
    const bar = read("K4Bar.qml");
    const controller = read("K4PluginController.qml");

    assert.match(
        bar,
        /readonly property bool pointerOver:[\s\S]*?islandHover\.hovered[\s\S]*?edgeHover\.hovered[\s\S]*?bottom[\s\S]*?!hideMode[\s\S]*?bottomBridgeHover\.hovered/
    );
    assert.match(
        bar,
        /Item\s*\{[\s\S]*?id:\s*bottomHoverBridge[\s\S]*?visible:\s*panelWindow\.bottom && !panelWindow\.hideMode[\s\S]*?height:\s*K4Theme\.baseHeight[\s\S]*?HoverHandler\s*\{[\s\S]*?id:\s*bottomBridgeHover/
    );
    assert.match(
        bar,
        /onPointerOverChanged:\s*\{[\s\S]*?if \(!hideMode\)[\s\S]*?if \(pointerOver\)[\s\S]*?controller\.hoverEntered\(panelWindow\.screen\.name\)[\s\S]*?else[\s\S]*?controller\.hoverExited\(\)/
    );
    assert.match(
        bar,
        /Region\s*\{[\s\S]*?item:\s*\(IslandState\.suppressed\s*\|\|\s*!panelWindow\.bottom\s*\|\|\s*panelWindow\.hideMode\)[\s\S]*?\?\s*null\s*:\s*bottomHoverBridge[\s\S]*?Intersection\.Combine/
    );

    assert.doesNotMatch(controller, /function hoverExitGraceMs\(/);
    assert.doesNotMatch(controller, /hoverClearTimer\.interval = hoverExitGraceMs\(\)/);
    assert.match(
        controller,
        /function hoverExited\(\)[\s\S]*?hoverClearTimer\.restart\(\)[\s\S]*?armPluginHoverExit\(\)/
    );
    assert.match(
        controller,
        /property var hoverClearTimer:\s*Timer\s*\{[\s\S]*?interval:\s*240/
    );
});
