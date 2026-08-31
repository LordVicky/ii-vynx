const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

test("k4 sizing controls persist independent width and UI scales", () => {
    const config = read("modules/common/Config.qml");
    const settings = read("modules/ii/k4bar/K4Settings.qml");

    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property real widthScale:\s*1\.0[\s\S]*?property real uiScale:\s*1\.0/);
    assert.match(settings, /readonly property real widthScale:\s*Config\.options\.bar\.k4\.widthScale/);
    assert.match(settings, /readonly property real uiScale:\s*Config\.options\.bar\.k4\.uiScale/);
    assert.match(settings, /minWidthScale:\s*0\.8/);
    assert.match(settings, /maxWidthScale:\s*1\.6/);
    assert.match(settings, /minUiScale:\s*0\.85/);
    assert.match(settings, /maxUiScale:\s*1\.4/);
    assert.match(settings, /if \(!isFinite\(value\)\)[\s\S]*?return 1\.0/);
    assert.match(settings, /function setWidthScale\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.widthScale = boundedScale/);
    assert.match(settings, /function setUiScale\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.uiScale = boundedScale/);
});

test("k4 width scale adds horizontal design space without stretching content", () => {
    const bar = read("modules/ii/k4bar/K4Bar.qml");

    assert.match(bar, /readonly property real designBodyWidth:[\s\S]*?desiredBodyWidth : pluginVisible\.islandWidth\)[\s\S]*?\* widthScale/);
    assert.match(bar, /readonly property int islandBodyWidth:[\s\S]*?designBodyWidth \* uiScale/);
    assert.match(bar, /width:\s*panelWindow\.designBodyWidth[\s\S]*?height:\s*panelWindow\.designBodyHeight[\s\S]*?scale:\s*panelWindow\.uiScale/);
    assert.doesNotMatch(bar, /xScale:\s*panelWindow\.widthScale/);
});

test("k4 UI scale grows compositor, input, silhouette, and content geometry together", () => {
    const bar = read("modules/ii/k4bar/K4Bar.qml");

    assert.match(bar, /readonly property int islandBodyHeight:[\s\S]*?designBodyHeight \* uiScale/);
    assert.match(bar, /exclusiveZone:[\s\S]*?K4Theme\.baseHeight \* panelWindow\.uiScale/);
    assert.match(bar, /bottomHoverBridge[\s\S]*?idleContent\.desiredBodyWidth \* panelWindow\.widthScale[\s\S]*?panelWindow\.uiScale/);
    assert.match(bar, /readonly property real bodyRadius:[\s\S]*?32 \* panelWindow\.uiScale/);
    assert.match(bar, /Math\.min\(panelWindow\.scaledWing, island\.height \/ 2\)/);
    assert.match(bar, /transformOrigin:\s*Item\.Top/);
});

test("k4 settings exposes width and UI scale sliders with live drag updates", () => {
    const view = read("modules/ii/k4bar/K4SettingsView.qml");
    const slider = read("modules/ii/k4bar/K4SettingsScale.qml");

    assert.match(view, /K4SettingsScale\s*\{[\s\S]*?title:\s*"Island width"[\s\S]*?value:\s*K4Settings\.widthScale[\s\S]*?setWidthScale/);
    assert.match(view, /K4SettingsScale\s*\{[\s\S]*?title:\s*"UI scale"[\s\S]*?value:\s*K4Settings\.uiScale[\s\S]*?setUiScale/);
    assert.match(slider, /Slider\s*\{[\s\S]*?onMoved:\s*root\.valueEdited\(value\)/);
    assert.doesNotMatch(slider, /\blive:\s*true/);
    assert.match(slider, /Math\.round\(root\.value \* 100\) \+ "%"/);
});

test("compact clock and tray render intrinsically at the selected UI scale", () => {
    const idle = read("modules/ii/k4bar/K4IdlePill.qml");
    const tray = read("modules/ii/k4bar/K4TrayRow.qml");

    assert.match(idle, /Qt\.formatDateTime\(K4Clock\.date, "HH:mm"\)[\s\S]*?font\.pixelSize:\s*Math\.round\(12 \* K4Settings\.uiScale\)[\s\S]*?scale:\s*1 \/ K4Settings\.uiScale/);

    assert.match(tray, /readonly property real uiScale:\s*K4Settings\.uiScale/);
    assert.match(tray, /width:\s*Math\.round\(root\.iconSize \* root\.uiScale\)[\s\S]*?height:\s*Math\.round\(root\.iconSize \* root\.uiScale\)[\s\S]*?scale:\s*1 \/ root\.uiScale/);
    assert.match(tray, /sourceSize\.width:\s*Math\.ceil\(root\.iconSize \* root\.uiScale \* 2\)/);
    assert.match(tray, /sourceSize\.height:\s*Math\.ceil\(root\.iconSize \* root\.uiScale \* 2\)/);
});
