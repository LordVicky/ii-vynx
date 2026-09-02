const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

test("k4 persists attached and floating-pill shape choices", () => {
    const config = read("modules/common/Config.qml");
    const settings = read("modules/ii/k4bar/K4Settings.qml");
    const view = read("modules/ii/k4bar/K4SettingsView.qml");

    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property string shape:\s*"attached"/);
    assert.doesNotMatch(config, /property real uiScale:/);

    assert.match(settings, /readonly property string shape:\s*Config\.options\.bar\.k4\.shape/);
    assert.match(settings, /readonly property var shapes:[\s\S]*?label:\s*"Attached"[\s\S]*?value:\s*"attached"[\s\S]*?label:\s*"Floating pill"[\s\S]*?value:\s*"pill"/);
    assert.match(settings, /function setShape\(wanted\)[\s\S]*?value === "attached" \|\| value === "pill"[\s\S]*?Config\.options\.bar\.k4\.shape = value/);

    assert.match(view, /text:\s*"Island shape"/);
    assert.match(view, /model:\s*K4Settings\.shapes/);
    assert.match(view, /K4Settings\.shape === modelData\.value/);
    assert.match(view, /K4Settings\.setShape\(shapeChoice\.modelData\.value\)/);
});

test("floating pill preserves island proportions while detaching from the screen edge", () => {
    const bar = read("modules/ii/k4bar/K4Bar.qml");

    assert.match(bar, /readonly property bool pillShape:\s*K4Settings\.shape === "pill"/);
    assert.match(bar, /readonly property int shapeInset:\s*pillShape \? 6 : 0/);
    assert.match(bar, /exclusiveZone:[\s\S]*?K4Theme\.baseHeight \+ panelWindow\.shapeInset/);
    assert.match(bar, /id:\s*island[\s\S]*?anchors\.topMargin:\s*panelWindow\.bottom \? 0 : panelWindow\.shapeInset[\s\S]*?anchors\.bottomMargin:\s*panelWindow\.bottom \? panelWindow\.shapeInset : 0/);

    assert.match(bar, /id:\s*pillSilhouette[\s\S]*?visible:\s*panelWindow\.pillShape[\s\S]*?radius:\s*island\.bodyRadius[\s\S]*?color:\s*K4Theme\.islandBg/);
    assert.match(bar, /id:\s*silhouette[\s\S]*?visible:\s*!panelWindow\.pillShape/);

    assert.match(bar, /y:\s*panelWindow\.bottom[\s\S]*?panelWindow\.screen\.height - panelWindow\.shapeInset[\s\S]*?- island\.height[\s\S]*?: panelWindow\.shapeInset/);
    assert.match(bar, /id:\s*withdrawTranslate[\s\S]*?island\.height \+ panelWindow\.shapeInset \+ 6/);
    assert.match(bar, /height:\s*K4Theme\.baseHeight \+ panelWindow\.shapeInset[\s\S]*?id:\s*bottomBridgeHover/);
});
