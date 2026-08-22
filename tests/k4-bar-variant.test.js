const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

test("standard is the default bar variant and k4 settings are independent", () => {
    const config = read("modules/common/Config.qml");

    assert.match(config, /property JsonObject bar:\s*JsonObject\s*\{[\s\S]*?property string variant:\s*"standard"/);
    assert.match(config, /property JsonObject k4:\s*JsonObject\s*\{[\s\S]*?property string position:\s*"top"[\s\S]*?property int alignment:\s*50/);
});

test("ii family gives bar ownership to exactly the selected variant", () => {
    const family = read("panelFamilies/IllogicalImpulseFamily.qml");

    assert.match(family, /readonly property bool usingStandardBar:\s*Config\.options\.bar\.variant === "standard"/);
    assert.match(family, /readonly property bool usingK4Bar:\s*Config\.options\.bar\.variant === "k4"/);
    assert.match(family, /PanelLoader \{ extraCondition: usingK4Bar; component: K4Bar \{\} \}/);

    for (const component of [
        "BarHugGlassLayer",
        "BarGlassLayer",
        "BarPlainGlassLayer",
        "Bar",
        "VerticalBarGlassLayer",
        "VerticalBar",
    ]) {
        const expression = new RegExp(`PanelLoader \\{ extraCondition: usingStandardBar[^\\n]*component: ${component} \\{\\} \\}`);
        assert.match(family, expression, `${component} must stay Standard-only`);
    }
});

test("k4 host follows upstream all-screen top-bottom ownership seam", () => {
    const source = read("modules/ii/k4bar/K4Bar.qml");
    const state = read("modules/ii/k4bar/IslandState.qml");

    assert.match(source, /model:\s*GlobalStates\.screenLocked \? \[\] : Quickshell\.screens/);
    assert.doesNotMatch(source, /Config\.options\.bar\.screenList/);
    assert.match(source, /Config\.options\.bar\.k4\.position === "bottom"/);
    assert.match(source, /property real smoothPlacement:\s*IslandState\.placement/);
    assert.match(state, /Config\.options\.bar\.k4\.alignment/);
    assert.match(source, /exclusiveZone:\s*K4Theme\.baseHeight/);
    assert.match(source, /WlrLayershell\.namespace:\s*"quickshell:k4bar"/);
});

test("bar settings switch mode and hide Standard-only sections", () => {
    const settings = read("modules/settings/BarConfig.qml");

    assert.match(settings, /readonly property bool standardBar:\s*Config\.options\.bar\.variant === "standard"/);
    assert.match(settings, /title:\s*Translation\.tr\("Bar variant"\)/);
    assert.match(settings, /displayName:\s*Translation\.tr\("k4 Dynamic Island"\)[\s\S]*?value:\s*"k4"/);
    assert.match(settings, /visible:\s*!page\.standardBar[\s\S]*?Config\.options\.bar\.k4\.position[\s\S]*?Config\.options\.bar\.k4\.alignment/);

    const standardOnlySections = settings.match(/visible:\s*page\.standardBar/g) || [];
    assert.ok(standardOnlySections.length >= 10, "Standard-only settings sections must be hidden in k4 mode");
});

test("dashboard no longer carries bar-specific liquid-glass inset state", () => {
    const dashboard = read("modules/ii/sidebarDashboard/SidebarDashboard.qml");
    const glass = read("modules/ii/sidebarDashboard/SidebarDashboardGlass.qml");

    assert.doesNotMatch(dashboard, /reserveHorizontalBar|horizontalBarReserve|topBarReserve|bottomBarReserve/);
    assert.doesNotMatch(glass, /topInset|bottomInset|surfaceCommitScheduled/);
    assert.match(glass, /exclusionMode:\s*ExclusionMode\.Normal/);
});
