const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("clock hover keeps measured edge zones around a centered clock", () => {
    const view = read("modules/ii/k4bar/K4ClockView.qml");
    const builtins = read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(view, /readonly property int measuredLeft:\s*leftDate\.implicitWidth/);
    assert.match(view, /readonly property int measuredCenter:\s*clockText\.implicitWidth/);
    assert.match(view, /readonly property int measuredRight:\s*rightIndicators\.implicitWidth/);
    assert.match(view, /readonly property int zoneGap:\s*24/);

    assert.match(view, /id:\s*leftDate[\s\S]*?anchors\.left:\s*parent\.left/);
    assert.match(view, /id:\s*clockText[\s\S]*?anchors\.horizontalCenter:\s*parent\.horizontalCenter/);
    assert.match(view, /id:\s*rightIndicators[\s\S]*?anchors\.right:\s*parent\.right/);
    assert.doesNotMatch(view, /id:\s*clockText[\s\S]*?anchors\.left:\s*leftDate\.right/);
    assert.doesNotMatch(view, /id:\s*rightIndicators[\s\S]*?anchors\.left:\s*clockText\.right/);

    assert.match(builtins, /property QtObject clockPlugin:\s*K4Plugin \{[\s\S]*?id:\s*clockPluginObject/);
    assert.match(builtins, /property int leftMeasured:\s*0[\s\S]*?property int centerMeasured:\s*0[\s\S]*?property int rightMeasured:\s*0/);
    assert.match(builtins, /readonly property int leftWidth:\s*leftMeasured > 0 \? leftMeasured : 96/);
    assert.match(builtins, /readonly property int centerWidth:\s*centerMeasured > 0[\s\S]*?centerMeasured : 92/);
    assert.match(builtins, /readonly property int rightWidth:\s*Math\.min\(rightRaw, 480\)/);
    assert.match(builtins, /readonly property int sideWidth:\s*Math\.max\(leftWidth, rightWidth\)/);
    assert.match(builtins, /readonly property int zoneGap:\s*24/);
    assert.match(builtins, /islandWidth:\s*44 \+ centerWidth \+ 2 \* \(sideWidth \+ zoneGap\)/);

    assert.match(builtins, /K4ClockView \{[\s\S]*?Binding \{[\s\S]*?target:\s*clockPluginObject[\s\S]*?property:\s*"leftMeasured"[\s\S]*?value:\s*measuredLeft/);
    assert.match(builtins, /Binding \{[\s\S]*?target:\s*clockPluginObject[\s\S]*?property:\s*"centerMeasured"[\s\S]*?value:\s*measuredCenter/);
    assert.match(builtins, /Binding \{[\s\S]*?target:\s*clockPluginObject[\s\S]*?property:\s*"rightMeasured"[\s\S]*?value:\s*measuredRight/);

    assert.match(builtins, /readonly property int notificationStripHeight:\s*K4Settings\.notificationsOnHover[\s\S]*?K4Notifications\.stripHeight\(3\)/);
    assert.match(builtins, /islandHeight:\s*68 \+ \(notificationStripHeight > 0 \? notificationStripHeight \+ 18 : 0\)/);
});
