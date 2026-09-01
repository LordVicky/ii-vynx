const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

test("k4 exposes independent idle and expanded width controls", () => {
    const config = read("modules/common/Config.qml");
    const settings = read("modules/ii/k4bar/K4Settings.qml");
    const view = read("modules/ii/k4bar/K4SettingsView.qml");
    const slider = read("modules/ii/k4bar/K4SettingsScale.qml");

    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property real widthScale:\s*1\.0[\s\S]*?property real idleWidthScale:\s*1\.0/);
    assert.match(settings, /readonly property real widthScale:\s*Config\.options\.bar\.k4\.widthScale/);
    assert.match(settings, /readonly property real idleWidthScale:\s*Config\.options\.bar\.k4\.idleWidthScale/);
    assert.match(settings, /minWidthScale:\s*1\.0/);
    assert.match(settings, /maxWidthScale:\s*1\.6/);
    assert.match(settings, /function setWidthScale\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.widthScale = boundedScale/);
    assert.match(settings, /function setIdleWidthScale\(wanted\)[\s\S]*?Config\.options\.bar\.k4\.idleWidthScale = boundedScale/);
    assert.doesNotMatch(settings, /uiScale|minUiScale|maxUiScale|function setUiScale\(/);

    assert.match(view, /K4SettingsScale\s*\{[\s\S]*?title:\s*"Idle pill width"[\s\S]*?value:\s*K4Settings\.idleWidthScale[\s\S]*?setIdleWidthScale/);
    assert.match(view, /K4SettingsScale\s*\{[\s\S]*?title:\s*"Island width"[\s\S]*?value:\s*K4Settings\.widthScale[\s\S]*?setWidthScale/);
    assert.doesNotMatch(view, /title:\s*"UI scale"|setUiScale\(/);
    assert.match(slider, /Slider\s*\{[\s\S]*?onMoved:\s*root\.valueEdited\(value\)/);
    assert.doesNotMatch(slider, /\blive:\s*true/);
});

test("k4 splits idle width from expanded plugin width", () => {
    const bar = read("modules/ii/k4bar/K4Bar.qml");

    assert.match(bar, /readonly property real widthScale:\s*K4Settings\.widthScale/);
    assert.match(bar, /readonly property real idleWidthScale:\s*K4Settings\.idleWidthScale/);
    assert.match(bar, /readonly property int islandBodyWidth:\s*Math\.round\([\s\S]*?showingIdle[\s\S]*?idleContent\.desiredBodyWidth \* idleWidthScale[\s\S]*?: pluginVisible\.islandWidth \* widthScale\)/);
    assert.match(bar, /bottomHoverBridge[\s\S]*?idleContent\.desiredBodyWidth \* panelWindow\.idleWidthScale[\s\S]*?K4Theme\.wing \* 2/);
    assert.doesNotMatch(bar, /bottomHoverBridge[\s\S]*?idleContent\.desiredBodyWidth \* panelWindow\.widthScale/);
    assert.doesNotMatch(bar, /uiScale|designBodyHeight|scaledWing|xScale:\s*panelWindow\.widthScale/);
});

test("collapsed width grows around a fixed center and right edge", () => {
    const idle = read("modules/ii/k4bar/K4IdlePill.qml");
    const tray = read("modules/ii/k4bar/K4TrayRow.qml");

    assert.match(idle, /readonly property int sideMeasured:\s*Math\.max\(leftMeasured, rightMeasured\)/);
    assert.match(idle, /readonly property int desiredBodyWidth:\s*sideMeasured \* 2 \+ 90/);
    assert.match(idle, /id:\s*centerZone[\s\S]*?anchors\.horizontalCenter:\s*parent\.horizontalCenter/);
    assert.match(idle, /Qt\.formatDateTime\(K4Clock\.date, "HH:mm"\)[\s\S]*?font\.pixelSize:\s*14/);
    assert.match(idle, /id:\s*rightIndicators[\s\S]*?anchors\.right:\s*parent\.right/);
    assert.doesNotMatch(idle, /centerZone[\s\S]*?anchors\.leftMargin:\s*root\.leftMeasured \+ 11/);
    assert.doesNotMatch(idle, /uiScale/);
    assert.doesNotMatch(tray, /uiScale/);
});
