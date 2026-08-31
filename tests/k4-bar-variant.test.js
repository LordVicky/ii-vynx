const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

test("bar enablement defaults on while Standard remains the default variant", () => {
    const config = read("modules/common/Config.qml");

    assert.match(config, /property JsonObject bar:\s*JsonObject\s*\{[\s\S]*?property bool enable:\s*true[\s\S]*?property string variant:\s*"standard"/);
    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property string position:\s*"top"[\s\S]*?property int alignment:\s*50/);
});

test("ii family gives bar ownership to exactly the selected enabled variant", () => {
    const family = read("panelFamilies/IllogicalImpulseFamily.qml");

    assert.match(family, /readonly property bool barEnabled:\s*Config\.options\.bar\.enable/);
    assert.match(family, /readonly property bool usingStandardBar:\s*Config\.options\.bar\.variant === "standard"/);
    assert.match(family, /readonly property bool usingK4Bar:\s*Config\.options\.bar\.variant === "k4"/);
    assert.match(family, /PanelLoader \{ extraCondition: barEnabled && usingK4Bar; component: K4Bar \{\} \}/);
    assert.match(family, /PanelLoader \{ extraCondition: barEnabled && usingK4Bar; component: K4LauncherRouting \{\} \}/);
    assert.match(family, /PanelLoader \{ extraCondition: barEnabled && usingStandardBar && !Config\.options\.bar\.vertical && barExtraCondition; component: Bar \{\} \}/);
    assert.match(family, /PanelLoader \{ extraCondition: barEnabled && usingStandardBar && Config\.options\.bar\.vertical && barExtraCondition; component: VerticalBar \{\} \}/);

    assert.doesNotMatch(family, /BarHugGlassLayer|BarGlassLayer|BarPlainGlassLayer|VerticalBarGlassLayer|liquidGlass|LiquidGlass|hyprglass/);
});

test("waffle bar follows the same shell-wide bar enablement", () => {
    const family = read("panelFamilies/WaffleFamily.qml");
    assert.match(family, /PanelLoader \{ extraCondition: Config\.options\.bar\.enable; component: WaffleBar \{\} \}/);
});

test("k4 host follows upstream all-screen top-bottom ownership seam", () => {
    const source = read("modules/ii/k4bar/K4Bar.qml");
    const state = read("modules/ii/k4bar/IslandState.qml");

    assert.match(source, /model:\s*GlobalStates\.screenLocked \? \[\] : Quickshell\.screens/);
    assert.doesNotMatch(source, /Config\.options\.bar\.screenList/);
    assert.match(source, /Config\.options\.bar\.k4\.position === "bottom"/);
    assert.match(source, /property real smoothPlacement:\s*IslandState\.placement/);
    assert.match(state, /Config\.options\.bar\.k4\.alignment/);
    assert.match(source, /readonly property string effectiveSpaceMode:\s*K4Settings\.spaceMode/);
    assert.match(source, /exclusiveZone:\s*panelWindow\.effectiveSpaceMode === "reserve"[\s\S]*?K4Theme\.baseHeight\s*:\s*0/);
    assert.match(source, /WlrLayershell\.namespace:\s*"quickshell:k4bar"/);
});

test("bar settings expose shell-wide enablement and variant selection", () => {
    const settings = read("modules/settings/BarConfig.qml");

    assert.match(settings, /readonly property bool standardBar:\s*Config\.options\.bar\.variant === "standard"/);
    assert.match(settings, /ConfigSwitch\s*\{[\s\S]*?text:\s*Translation\.tr\("Enable bar"\)[\s\S]*?checked:\s*Config\.options\.bar\.enable[\s\S]*?Config\.options\.bar\.enable = checked/);
    assert.match(settings, /title:\s*Translation\.tr\("Bar variant"\)/);
    assert.match(settings, /displayName:\s*Translation\.tr\("k4 Dynamic Island"\)[\s\S]*?value:\s*"k4"/);
    assert.match(settings, /visible:\s*!page\.standardBar[\s\S]*?Config\.options\.bar\.k4\.position[\s\S]*?Config\.options\.bar\.k4\.alignment/);

    const standardOnlySections = settings.match(/visible:\s*page\.standardBar/g) || [];
    assert.ok(standardOnlySections.length >= 10, "Standard-only settings sections must be hidden in k4 mode");
});
