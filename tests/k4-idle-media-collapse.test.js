const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const idlePath = path.join(
    repoRoot,
    "dots/.config/quickshell/ii/modules/ii/k4bar/K4IdlePill.qml"
);

test("paused media contributes zero width to the collapsed pill", () => {
    const source = fs.readFileSync(idlePath, "utf8");

    assert.match(
        source,
        /readonly property int leftMeasured:\s*isPlaying\s*\?\s*\(leftMedia\.implicitWidth > 0\s*\?\s*Math\.ceil\(leftMedia\.implicitWidth\)\s*:\s*53\)\s*:\s*0/
    );
    assert.doesNotMatch(
        source,
        /readonly property int leftMeasured:\s*leftMedia\.implicitWidth > 0[\s\S]*?isPlaying \? 53 : 0/
    );
});
